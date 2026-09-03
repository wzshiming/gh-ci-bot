#!/usr/bin/env bash

# blunderbuss.sh - Selects and requests reviewers for a PR from the OWNERS
# files nearest to the changed files, falling back to the REVIEWERS
# environment variable. Used in two modes:
#   auto   - on PR open or ready-for-review, mirroring prow's blunderbuss
#            plugin (default): skips draft PRs and exits quietly when
#            disabled or when no reviewers are found
#   manual - for the /auto-cc command: always runs and reports a failure
#            when no reviewers can be found
#
# Configuration:
#   BLUNDERBUSS_REVIEWER_COUNT - number of reviewers to request (default 2,
#                                set to 0 to disable the auto mode)

mode="${1:-auto}"

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    if [[ "${mode}" == "manual" ]]; then
        echo "[FAIL] This command is only available on pull requests, not on issues."
        exit 1
    fi
    exit 0
fi

count="${BLUNDERBUSS_REVIEWER_COUNT:-2}"
if ! [[ "${count}" =~ ^[0-9]+$ ]] || [[ "${count}" -eq 0 ]]; then
    if [[ "${mode}" == "manual" ]]; then
        count=2
    else
        echo "Blunderbuss is disabled (BLUNDERBUSS_REVIEWER_COUNT=${BLUNDERBUSS_REVIEWER_COUNT:-})"
        exit 0
    fi
fi

# Mirror prow's blunderbuss default of ignoring draft PRs.
if [[ "${mode}" != "manual" ]] &&
    [[ "$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json isDraft --jq '.isDraft')" == "true" ]]; then
    echo "Skipping draft PR"
    exit 0
fi

branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"

# fetch_reviewers_from_file prints the reviewers listed in the OWNERS file
# of the given directory ("" for the repository root), empty on failure.
function fetch_reviewers_from_file() {
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

    printf '%s\n' "${content}" | yq e '.reviewers // [] | .[]' 2>/dev/null
}

declare -A dir_reviewers
declare -A dir_checked

# load_dir_reviewers fetches the OWNERS file of a directory once and caches
# its reviewers. The root directory is ".". Must not be called in a subshell.
function load_dir_reviewers() {
    local dir="${1}"
    if [[ -n "${dir_checked[${dir}]:-}" ]]; then
        return 0
    fi
    dir_checked["${dir}"]=1
    local fetch_dir=""
    if [[ "${dir}" != "." ]]; then
        fetch_dir="${dir}"
    fi
    dir_reviewers["${dir}"]="$(fetch_reviewers_from_file "${fetch_dir}" | tr '\n' ' ')"
}

# get_dir_reviewers prints the cached reviewers of a directory.
function get_dir_reviewers() {
    echo "${dir_reviewers[${1}]:-}"
}

# get_parent_dir prints the parent of a directory, "." for top-level
# directories and nothing for ".".
function get_parent_dir() {
    local dir="${1}"
    if [[ "${dir}" == "." ]]; then
        echo ""
    elif [[ "${dir}" =~ "/" ]]; then
        echo "${dir%/*}"
    else
        echo "."
    fi
}

# get_area_for_file walks up from the changed file to the nearest directory
# whose OWNERS file lists at least one reviewer. Sets _FILE_AREA, empty if
# no OWNERS file with reviewers is found.
function get_area_for_file() {
    local file="${1}"
    local dir
    _FILE_AREA=""
    if [[ "${file}" =~ "/" ]]; then
        dir="${file%/*}"
    else
        dir="."
    fi

    while [[ -n "${dir}" ]]; do
        load_dir_reviewers "${dir}"
        if [[ -n "$(get_dir_reviewers "${dir}")" ]]; then
            _FILE_AREA="${dir}"
            return 0
        fi
        dir="$(get_parent_dir "${dir}")"
    done
}

files="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[].filename' |
    sort -u)"

echo "Modify files:" >&2
while read -r f; do
    [[ -z "${f}" ]] && continue
    echo "- ${f}" >&2
done <<<"${files}"

# Collect the areas (nearest directories with reviewers) of the changed files.
areas=""
while read -r f; do
    [[ -z "${f}" ]] && continue
    get_area_for_file "${f}"
    if [[ -n "${_FILE_AREA}" ]]; then
        areas="${areas}
${_FILE_AREA}"
    fi
done <<<"${files}"
areas="$(echo "${areas}" | sed '/^$/d' | sort -u)"

picked=()

function in_picked() {
    local user="${1}"
    if [[ "${user}" == "${AUTHOR}" ]]; then
        return 0
    fi
    for u in "${picked[@]}"; do
        if [[ "${user}" == "${u}" ]]; then
            return 0
        fi
    done
    return 1
}

# Pick reviewers round-robin across areas so every changed area gets a
# reviewer before any area gets a second one, until count is reached.
while [[ "${#picked[@]}" -lt "${count}" && -n "${areas}" ]]; do
    added=0
    while read -r area; do
        [[ -z "${area}" ]] && continue
        if [[ "${#picked[@]}" -ge "${count}" ]]; then
            break
        fi
        for user in $(get_dir_reviewers "${area}" | tr ' ' '\n' | sort --random-sort); do
            if ! in_picked "${user}"; then
                picked+=("${user}")
                added=1
                echo "Add ${user} for ${area}" >&2
                break
            fi
        done
    done <<<"${areas}"
    if [[ "${added}" -eq 0 ]]; then
        break
    fi
done

# Fill up from the REVIEWERS environment variable if needed.
if [[ "${#picked[@]}" -lt "${count}" ]]; then
    for user in $(echo "${REVIEWERS:-}" | tr ' ' '\n' | sed '/^$/d' | sort -u | sort --random-sort); do
        if [[ "${#picked[@]}" -ge "${count}" ]]; then
            break
        fi
        if ! in_picked "${user}"; then
            picked+=("${user}")
            echo "Add ${user} from REVIEWERS" >&2
        fi
    done
fi

if [[ "${#picked[@]}" -eq 0 ]]; then
    if [[ "${mode}" == "manual" ]]; then
        echo "[FAIL] Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured."
        exit 1
    fi
    echo "No reviewers found to request, skipping" >&2
    exit 0
fi

login="$(printf '%s\n' "${picked[@]}" | tr '\n' ',' | sed 's/,$//')"

echo "Auto-requesting reviews from ${login}."

add-reviewer.sh "${login}"
