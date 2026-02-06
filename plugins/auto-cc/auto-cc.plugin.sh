#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

# Source the owners utility
ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m "${ROOT}")"
source "${ROOT}/../../bin/owners.sh"

# Track users already assigned to avoid duplicates
user_pool=()

# Check if user is in the pool or is the author
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

# Track directories already processed
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

# Walk up from a directory to find a reviewer from OWNERS files
function get_reviewer_with_recursively() {
    local dir="${1}"
    local ori="${2}"
    local reviewers
    local parent
    
    if in_used_dir "${dir}"; then
        return 0
    fi
    used_dir+=("${dir}")

    reviewers="$(read_owners_file "${dir}" "reviewers")"
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

    parent="$(get_parent_dir "${dir}")"
    if [[ "${parent}" == "${dir}" ]]; then
        return 0
    fi
    get_reviewer_with_recursively "${parent}" "${ori}"
}

# Get reviewers for all changed files
function get_reviewers() {
    for file in "$@"; do
        get_reviewer_with_recursively "$(get_parent_dir "${file}")" "${file}"
    done

    for u in "${user_pool[@]}"; do
        echo "${u}"
    done
}

# Get list of changed files
files="$(get_pr_changed_files)"

echo "Modified files:" >&2
for f in ${files}; do
    echo "- ${f}" >&2
done

# Get reviewers from OWNERS files
login="$(get_reviewers ${files} | tr '\n' ',' | sed 's/,$//')"

# Fallback to REVIEWERS environment variable if no OWNERS reviewers found
if [[ "${login}" == "" ]]; then
    echo "Fallback to REVIEWERS environment variable" >&2
    login=$(echo "${REVIEWERS}" | shuf | head -n 2 | tr '\n' ',' | sed 's/,$//')
    if [[ -z "${login}" ]]; then
        echo "[FAIL] Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured."
        exit 1
    fi
fi

echo "Auto-ccing ${login}."

add-reviewer.sh "${login}"
