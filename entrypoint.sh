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

# sync_release_note_label keeps the release-note labels in sync with the
# release-note block in the PR body, mirroring prow's release-note plugin.
function sync_release_note_label() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-release-note.sh
    fi
}

# sync_dco_label keeps the dco-signoff labels in sync with the signoff
# state of the PR's commits, mirroring prow's dco plugin. Only runs when
# the commits can have changed: on open and on push.
function sync_dco_label() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-dco.sh
    fi
}

# sync_size_label keeps the size/* label in sync with the PR's diff size,
# mirroring prow's size plugin.
function sync_size_label() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-size.sh
    fi
}

# auto_request_reviewers requests reviewers from OWNERS files when a PR is
# opened or marked ready for review, mirroring prow's blunderbuss plugin.
function auto_request_reviewers() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        blunderbuss.sh
    fi
}

# sync_matching_labels keeps needs-* labels in sync with the issue/PR labels,
# mirroring prow's require-matching-label plugin. It runs at the end of
# every event, ahead of the auto-merge check: labels applied by the run
# itself (e.g. from OWNERS files on a push) trigger no new workflow run,
# so the run that applied them has to re-sync the needs-* labels too.
function sync_matching_labels() {
    check-matching-labels.sh
}

# sync_auto_merge merges the PR once it has both the lgtm and approved
# labels, every area is approved and no do-not-merge/* label is left. It
# runs as the last step of every PR event, the way tide reconciles its
# pool, so the merge happens no matter which command, sync or UI action
# removed the last blocker.
function sync_auto_merge() {
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        check-auto-merge.sh
    fi
}

function main() {
    if [[ "${TYPE}" == "created" ]]; then
        echo "Greetings to ${LOGIN}!"
        greeting.sh
        sync_wip_label
        sync_release_note_label
        sync_dco_label
        sync_size_label
        sync_approve_status
        auto_request_reviewers
        echo "Response to action"
        response.sh
        sync_matching_labels
        sync_auto_merge
    elif [[ "${TYPE}" == "comment" ]]; then
        echo "Response to action"
        response.sh
        sync_matching_labels
        sync_auto_merge
    elif [[ "${TYPE}" == "synchronize" ]]; then
        echo "PR synchronized, removing lgtm label"
        remove-labels.sh lgtm
        sync_wip_label
        sync_release_note_label
        sync_dco_label
        sync_size_label
        sync_approve_status
        sync_matching_labels
        sync_auto_merge
    elif [[ "${TYPE}" == "edited" || "${TYPE}" == "converted_to_draft" ]]; then
        echo "PR edited, syncing work-in-progress label"
        sync_wip_label
        sync_release_note_label
        sync_matching_labels
        sync_auto_merge
    elif [[ "${TYPE}" == "ready_for_review" ]]; then
        echo "PR ready for review, syncing work-in-progress label and requesting reviewers"
        sync_wip_label
        sync_release_note_label
        auto_request_reviewers
        sync_matching_labels
        sync_auto_merge
    elif [[ "${TYPE}" == "labeled" || "${TYPE}" == "unlabeled" ]]; then
        echo "Labels changed, syncing needs-* labels"
        sync_matching_labels
        sync_auto_merge
    fi
}

check_args

main
