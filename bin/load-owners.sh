#!/usr/bin/env bash

# Load reviewers and approvers from the OWNERS file in the repository root.
# This merges values from the OWNERS file with any existing environment variables.
# The OWNERS file follows the Kubernetes OWNERS format:
#   reviewers:
#     - reviewer1
#     - reviewer2
#   approvers:
#     - approver1
#     - approver2

if [[ -z "${GH_REPOSITORY}" ]]; then
    return 0
fi

OWNERS_FILE="${OWNERS_FILE:-OWNERS}"

function load_owners() {
    local owners_content
    local branch

    if [[ -f "${OWNERS_FILE}" ]]; then
        owners_content="$(cat "${OWNERS_FILE}")"
    else
        branch="$(gh api /repos/${GH_REPOSITORY} 2>/dev/null | jq -r '.default_branch' 2>/dev/null)"
        if [[ -z "${branch}" || "${branch}" == "null" ]]; then
            return 0
        fi
        owners_content="$(curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${OWNERS_FILE}" 2>/dev/null)" || return 0
    fi

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

load_owners
