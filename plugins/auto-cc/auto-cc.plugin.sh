#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

branch="$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')"

function get_reviewer_from_file() {
    local dir="${1}"
    echo curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${dir}/OWNERS" >&2
    curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${dir}/OWNERS" | yq e '.reviewers | .[]'
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

file="$(curl -fsSL "https://github.com/${GH_REPOSITORY}/pull/${ISSUE_NUMBER}.patch" | grep '^[-\+]\{3\} [ab]' | sed "s#--- a/##g" | sed "s#+++ b/##g" | sort -u)"

echo "Modify files:" >&2
for f in ${file}; do
    echo "- ${f}" >&2
done

login="$(get_reviewers ${file} | tr '\n' ',' | sed 's/,$//')"

if [[ "${login}" == "" ]]; then
    echo "Fallback use REVIEWERS environment variable" >&2
    login=$(echo "${REVIEWERS}" | shuf | head -n 2 | tr '\n' ',' | sed 's/,$//')
    if [[ -z "${login}" ]]; then
        echo "[FAIL] No reviewers specified. Skipping auto-cc."
        exit 1
    fi
fi

echo "Auto-ccing ${login}."

add-reviewer.sh "${login}"
