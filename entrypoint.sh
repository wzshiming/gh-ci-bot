#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m ${ROOT})"

PATH="${ROOT}/bin:${PATH}"

function check_args() {
    if [[ "${LOGIN}" == "" ]]; then
        echo "No login specified"
        exit 1
    fi

    if [[ "${ISSUE_KIND}" == "" ]]; then
        echo "No issue kind specified"
        exit 1
    fi

    if [[ "${ISSUE_NUMBER}" == "" ]]; then
        echo "No issue number specified"
        exit 1
    fi

    if [[ "${GH_REPOSITORY}" == "" ]]; then
        echo "No repository specified"
        exit 1
    fi

    if [[ "${TYPE}" == "" ]]; then
        echo "No type"
        exit 1
    fi
}

# sync_approve_status recomputes the per-area approval state for PRs.
# Approvals are sticky across pushes, mirroring prow's approve plugin.
function sync_approve_status() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        source "${ROOT}/bin/owners.sh"
        load_owners_for_pr
        approve-status.sh sync
    fi
}

# sync_wip_label keeps the do-not-merge/work-in-progress label in sync with
# the PR's draft state and title, mirroring prow's wip plugin.
function sync_wip_label() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-wip.sh
    fi
}

# sync_verify_owners validates OWNERS/OWNERS_ALIASES files changed in the PR
# and keeps the do-not-merge/invalid-owners-file label in sync, mirroring
# prow's verify-owners plugin.
function sync_verify_owners() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        verify-owners.sh
    fi
}

function main() {
    if [[ "${TYPE}" == "created" ]]; then
        echo "Greetings to ${LOGIN}!"
        greeting.sh
        sync_wip_label
        sync_verify_owners
        sync_approve_status
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "comment" ]]; then
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "synchronize" ]]; then
        echo "PR synchronized, removing lgtm label"
        remove-labels.sh lgtm
        sync_wip_label
        sync_verify_owners
        sync_approve_status
    elif [[ "${TYPE}" == "edited" ]]; then
        echo "PR edited, syncing work-in-progress label"
        sync_wip_label
    fi
}

check_args

main
