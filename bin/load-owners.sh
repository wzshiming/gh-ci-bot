#!/usr/bin/env bash

# Load reviewers and approvers from OWNERS files in the repository.
# This merges values from OWNERS files with any existing environment variables.
# The OWNERS file follows the Kubernetes OWNERS format:
#   reviewers:
#     - reviewer1
#     - reviewer2
#   approvers:
#     - approver1
#     - approver2
#
# For pull requests, OWNERS files are loaded hierarchically: starting from the
# common prefix directory of all changed files and walking up to the root.
# For issues or when changed files cannot be determined, only the root OWNERS
# file is loaded.

if [[ -z "${GH_REPOSITORY}" ]]; then
    return 0
fi

OWNERS_FILE_NAME="${OWNERS_FILE_NAME:-OWNERS}"

function _load_owners_get_content() {
    local dir="${1}"
    local path

    if [[ -z "${dir}" ]]; then
        path="${OWNERS_FILE_NAME}"
    else
        path="${dir}/${OWNERS_FILE_NAME}"
    fi

    if [[ -f "${path}" ]]; then
        cat "${path}"
        return 0
    fi

    if [[ -z "${_LOAD_OWNERS_BRANCH}" ]]; then
        _LOAD_OWNERS_BRANCH="$(gh api /repos/${GH_REPOSITORY} 2>/dev/null | jq -r '.default_branch' 2>/dev/null)"
        if [[ -z "${_LOAD_OWNERS_BRANCH}" || "${_LOAD_OWNERS_BRANCH}" == "null" ]]; then
            _LOAD_OWNERS_BRANCH=""
            return 1
        fi
    fi

    curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${_LOAD_OWNERS_BRANCH}/${path}" 2>/dev/null
}

function _load_owners_merge() {
    local owners_content="${1}"

    if [[ -z "${owners_content}" ]]; then
        return 0
    fi

    local owners_reviewers
    local owners_approvers
    owners_reviewers="$(echo "${owners_content}" | yq e '.reviewers // [] | .[]' 2>/dev/null)"
    owners_approvers="$(echo "${owners_content}" | yq e '.approvers // [] | .[]' 2>/dev/null)"

    if [[ -n "${owners_reviewers}" ]]; then
        if [[ -n "${REVIEWERS}" ]]; then
            REVIEWERS="$(echo -e "${REVIEWERS}\n${owners_reviewers}" | sort -u)"
        else
            REVIEWERS="${owners_reviewers}"
        fi
        export REVIEWERS
    fi

    if [[ -n "${owners_approvers}" ]]; then
        if [[ -n "${APPROVERS}" ]]; then
            APPROVERS="$(echo -e "${APPROVERS}\n${owners_approvers}" | sort -u)"
        else
            APPROVERS="${owners_approvers}"
        fi
        export APPROVERS
    fi
}

function _load_owners_common_prefix() {
    local prefix=""
    local first=true
    for f in "$@"; do
        local dir
        if [[ "${f}" =~ "/" ]]; then
            dir="${f%/*}"
        else
            echo ""
            return 0
        fi
        if [[ "${first}" == "true" ]]; then
            prefix="${dir}"
            first=false
            continue
        fi
        # Find common prefix between current prefix and this dir
        local new_prefix=""
        local IFS_OLD="${IFS}"
        IFS='/'
        local -a parts_a=(${prefix})
        local -a parts_b=(${dir})
        IFS="${IFS_OLD}"
        local i=0
        while [[ ${i} -lt ${#parts_a[@]} && ${i} -lt ${#parts_b[@]} ]]; do
            if [[ "${parts_a[${i}]}" == "${parts_b[${i}]}" ]]; then
                if [[ -z "${new_prefix}" ]]; then
                    new_prefix="${parts_a[${i}]}"
                else
                    new_prefix="${new_prefix}/${parts_a[${i}]}"
                fi
            else
                break
            fi
            i=$((i + 1))
        done
        prefix="${new_prefix}"
        if [[ -z "${prefix}" ]]; then
            echo ""
            return 0
        fi
    done
    echo "${prefix}"
}

function _load_owners_get_changed_files() {
    if [[ "${ISSUE_KIND}" != "pr" || -z "${ISSUE_NUMBER}" ]]; then
        return 1
    fi
    curl -fsSL "https://github.com/${GH_REPOSITORY}/pull/${ISSUE_NUMBER}.patch" 2>/dev/null |
        grep '^[-+]\{3\} [ab]' |
        sed "s#--- a/##g" |
        sed "s#+++ b/##g" |
        sort -u
}

function load_owners() {
    local changed_files
    changed_files="$(_load_owners_get_changed_files)"

    if [[ -n "${changed_files}" ]]; then
        # Walk from common prefix up to root, loading OWNERS at each level
        local dir
        dir="$(_load_owners_common_prefix ${changed_files})"
        while true; do
            local content
            content="$(_load_owners_get_content "${dir}")" && _load_owners_merge "${content}"
            if [[ -z "${dir}" ]]; then
                break
            fi
            # Move to parent directory
            if [[ "${dir}" =~ "/" ]]; then
                dir="${dir%/*}"
            else
                dir=""
            fi
        done
    else
        # Fallback: load only root OWNERS file
        local content
        content="$(_load_owners_get_content "")" && _load_owners_merge "${content}"
    fi
}

load_owners
