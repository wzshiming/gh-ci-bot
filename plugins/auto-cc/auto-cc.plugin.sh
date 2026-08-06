#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

branch="$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')"

function get_reviewer_from_file() {
    local dir="${1}"
    local path
    local content
    if [[ -z "${dir}" ]]; then
        path="OWNERS"
    else
        path="${dir}/OWNERS"
    fi

    echo "Fetch ${path} from ${GH_REPOSITORY}@${branch}" >&2
    if ! content="$(gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${branch}" 2>/dev/null)"; then
        return 0
    fi

    printf '%s\n' "${content}" | yq e '.reviewers | .[]'
}

user_pool=()

function in_user_pool() {
    local user="${1}"
    if [[ "${user}" == "${AUTHOR}" ]]; then
        return 0
    fi
    for u in "${user_pool[@]}"; do
        if [[ "${user}" == "${u}" ]]; then
            return 0
        fi
    done
    return 1
}

used_dir=()

function in_used_dir() {
    local dir="${1}"
    for d in "${used_dir[@]}"; do
        if [[ "${dir}" == "${d}" ]]; then
            return 0
        fi
    done
    return 1
}

function get_parent() {
    local dir="${1}"

    if [[ "${dir}" =~ "/" ]]; then
        echo "${dir%/*}"
    else
        echo ""
    fi
}

function get_reviewer_with_recursively() {
    local dir="${1}"
    local ori="${2}"
    local reviewers
    local parent
    if in_used_dir "${dir}"; then
        return 0
    fi
    used_dir+=("${dir}")

    reviewers="$(get_reviewer_from_file "${dir}")"
    if [[ "${reviewers}" != "" ]]; then
        for user in $(echo "${reviewers}" | sort --random-sort); do
            if ! in_user_pool "${user}"; then
                user_pool+=("${user}")
                if [[ "${ori}" == "${dir}" ]]; then
                    echo "Add ${user} for ${ori}" >&2
                else
                    echo "Add ${user} for ${ori} take on ${dir}" >&2
                fi
                return 0
            fi
        done
        return 0
    fi

    parent="$(get_parent "${dir}")"
    if [[ "${parent}" == "${dir}" ]]; then
        return 0
    fi
    get_reviewer_with_recursively "${parent}" "${dir}"
}

function get_reviewers() {
    for dir in "$@"; do
        get_reviewer_with_recursively "$(get_parent "${dir}")" "${dir}"
    done

    for u in "${user_pool[@]}"; do
        echo "${u}"
    done
}

# AI reviewers to prioritize, in preference order. Can be overridden with
# the AI_REVIEWERS environment variable (newline separated logins).
AI_REVIEWERS="${AI_REVIEWERS-copilot
gemini
codex}"

# request_ai_reviewer tries to request a review from the given user and
# succeeds only if the API accepts the request.
function request_ai_reviewer() {
    local user="${1}"
    local status
    status="$(curl -s -o /dev/null -w '%{http_code}' \
        -X POST \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Authorization: token ${GH_TOKEN}" \
        "https://api.github.com/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/requested_reviewers" \
        -d "{\"reviewers\":[\"${user}\"],\"team_reviewers\":[]}")"
    [[ "${status}" == "201" ]]
}

ai_reviewer=""
while IFS= read -r ai; do
    ai="${ai//\@/}"
    ai="$(echo "${ai}" | tr -d '[:space:]')"
    if [[ -z "${ai}" || "${ai}" == "${AUTHOR}" ]]; then
        continue
    fi
    echo "Try AI reviewer ${ai}" >&2
    if request_ai_reviewer "${ai}"; then
        ai_reviewer="${ai}"
        echo "Auto-ccing AI reviewer ${ai}."
        break
    fi
done <<< "${AI_REVIEWERS}"

file="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[].filename' |
    sort -u)"

echo "Modify files:" >&2
for f in ${file}; do
    echo "- ${f}" >&2
done

login="$(get_reviewers ${file} | tr '\n' ',' | sed 's/,$//')"

if [[ "${login}" == "" ]]; then
    echo "Fallback use REVIEWERS environment variable" >&2
    login=$(echo "${REVIEWERS}" | shuf | head -n 2 | tr '\n' ',' | sed 's/,$//')
    if [[ -z "${login}" ]]; then
        if [[ -n "${ai_reviewer}" ]]; then
            echo "No human reviewers found, only AI reviewer ${ai_reviewer} was assigned." >&2
            exit 0
        fi
        echo "[FAIL] Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured."
        exit 1
    fi
fi

echo "Auto-ccing ${login}."

add-reviewer.sh "${login}"
