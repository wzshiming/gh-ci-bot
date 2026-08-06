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

# apply_owners_labels applies the labels declared in the OWNERS files of
# the changed directories to the PR, mirroring prow's owners-label plugin.
# Requires OWNERS_LABELS (exported by load_owners_for_pr).
function apply_owners_labels() {
    if [[ -z "${OWNERS_LABELS:-}" ]]; then
        return 0
    fi
    local labels=()
    local label
    while read -r label; do
        if [[ -n "${label}" ]]; then
            labels+=("${label}")
        fi
    done <<<"${OWNERS_LABELS}"
    add-labels.sh "${labels[@]}"
}

# sync_approve_status recomputes the per-area approval state for PRs.
# Approvals are sticky across pushes, mirroring prow's approve plugin.
function sync_approve_status() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        source "${ROOT}/bin/owners.sh"
        load_owners_for_pr
        apply_owners_labels
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

# sync_size_label keeps the size/* label in sync with the PR's diff size,
# mirroring prow's size plugin.
function sync_size_label() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-size.sh
    fi
}

# sync_matching_labels keeps needs-* labels in sync with the issue/PR labels,
# mirroring prow's require-matching-label plugin.
function sync_matching_labels() {
    check-matching-labels.sh
}

function main() {
    if [[ "${TYPE}" == "created" ]]; then
        echo "Greetings to ${LOGIN}!"
        greeting.sh
        sync_wip_label
        sync_size_label
        sync_approve_status
        sync_matching_labels
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "comment" ]]; then
        echo "Response to action"
        response.sh
        sync_matching_labels
    elif [[ "${TYPE}" == "synchronize" ]]; then
        echo "PR synchronized, removing lgtm label"
        remove-labels.sh lgtm
        sync_wip_label
        sync_size_label
        sync_approve_status
    elif [[ "${TYPE}" == "edited" ]]; then
        echo "PR edited, syncing work-in-progress label"
        sync_wip_label
    elif [[ "${TYPE}" == "labeled" ]]; then
        echo "Labels changed, syncing needs-* labels"
        sync_matching_labels
    fi
}

check_args

main
