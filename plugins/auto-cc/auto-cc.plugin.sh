#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

# Reuse the OWNERS parsing helpers (aliases, filters, no_parent_owners,
# emeritus_approvers) from owners.sh.
source "$(command -v owners.sh)"

load_owners_aliases

# get_reviewers_for_file prints the reviewers declared in the OWNERS file
# of a directory that apply to a changed file. The root directory is "".
# The directory must already be loaded with load_owners_dir.
function get_reviewers_for_file() {
    local dir="${1}"
    local file="${2}"

    get_file_users "${dir:-.}" "${file}" "reviewers"
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
    local file="${2}"
    local ori="${3}"
    local reviewers
    local parent
    if in_used_dir "${dir}"; then
        return 0
    fi
    used_dir+=("${dir}")

    local path
    if [[ -z "${dir}" ]]; then
        path="OWNERS"
    else
        path="${dir}/OWNERS"
    fi
    echo "Fetch ${path} from ${GH_REPOSITORY}@${branch}" >&2
    load_owners_dir "${dir:-.}"

    reviewers="$(get_reviewers_for_file "${dir}" "${file}")"
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

    if [[ -z "${dir}" ]]; then
        return 0
    fi

    if dir_no_parent_owners "${dir}"; then
        echo "OWNERS: ${dir} sets no_parent_owners, ignoring parent OWNERS files" >&2
        return 0
    fi

    parent="$(get_parent "${dir}")"
    get_reviewer_with_recursively "${parent}" "${file}" "${dir}"
}

function get_reviewers() {
    for file in "$@"; do
        get_reviewer_with_recursively "$(get_parent "${file}")" "${file}" "${file}"
    done

    for u in "${user_pool[@]}"; do
        echo "${u}"
    done
}

file="$(get_pr_changed_files)"

echo "Modify files:" >&2
for f in ${file}; do
    echo "- ${f}" >&2
done

login="$(get_reviewers ${file} | tr '\n' ',' | sed 's/,$//')"

if [[ "${login}" == "" ]]; then
    echo "Fallback use REVIEWERS environment variable" >&2
    login=$(echo "${REVIEWERS}" | shuf | head -n 2 | tr '\n' ',' | sed 's/,$//')
    if [[ -z "${login}" ]]; then
        echo "[FAIL] Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured."
        exit 1
    fi
fi

echo "Auto-ccing ${login}."

add-reviewer.sh "${login}"
