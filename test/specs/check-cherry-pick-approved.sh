#!/usr/bin/env bash

# check-cherry-pick-approved.sh: a PR into a RELEASE_BRANCHES base carries
# do-not-merge/cherry-pick-not-approved until it has cherry-pick-approved,
# mirroring prow's cherrypickunapproved plugin; labels only, no comments.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

APPROVED_LABEL="cherry-pick-approved"
UNAPPROVED_LABEL="do-not-merge/cherry-pick-not-approved"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
}

begin_case "does nothing unless RELEASE_BRANCHES is set"
stub_label_scripts
mkbase release-1.0
run check-cherry-pick-approved.sh
assert_status 0
log_empty

begin_case "blocks an unapproved PR into a release branch"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase release-1.0
run check-cherry-pick-approved.sh
assert_status 0
log_has_line "stub add-labels.sh ${UNAPPROVED_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "leaves an already blocked PR alone"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase release-1.0 "${UNAPPROVED_LABEL}"
run check-cherry-pick-approved.sh
assert_status 0
log_has "view 1 --json baseRefName,labels"
log_lacks "stub"

begin_case "unblocks a PR once it is approved"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase release-1.0 "${APPROVED_LABEL}" "${UNAPPROVED_LABEL}"
run check-cherry-pick-approved.sh
assert_status 0
log_has_line "stub remove-labels.sh ${UNAPPROVED_LABEL}"
log_lacks "stub remove-labels.sh ${APPROVED_LABEL}"
log_lacks "stub add-labels.sh"

begin_case "leaves an approved PR alone"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase release-1.0 "${APPROVED_LABEL}"
run check-cherry-pick-approved.sh
assert_status 0
log_lacks "stub"

begin_case "drops both labels when the base is not a release branch"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase main "${APPROVED_LABEL}" "${UNAPPROVED_LABEL}"
run check-cherry-pick-approved.sh
assert_status 0
log_has_line "stub remove-labels.sh ${APPROVED_LABEL}"
log_has_line "stub remove-labels.sh ${UNAPPROVED_LABEL}"
log_lacks "stub add-labels.sh"

begin_case "leaves an unlabeled PR into a non-release branch alone"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
mkbase main
run check-cherry-pick-approved.sh
assert_status 0
log_lacks "stub"

begin_case "RELEASE_BRANCHES is a regular expression"
stub_label_scripts
export RELEASE_BRANCHES='^releases/'
mkbase releases/1.6
run check-cherry-pick-approved.sh
assert_status 0
log_has_line "stub add-labels.sh ${UNAPPROVED_LABEL}"

begin_case "skips the sync when the PR cannot be fetched"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
export MOCK_GH_FAIL=1
run check-cherry-pick-approved.sh
assert_status 0
assert_out_has "Failed to get the pull request, skipping the cherry-pick approval sync."
log_lacks "stub"

begin_case "does nothing for issues"
stub_label_scripts
export RELEASE_BRANCHES='^release-'
export ISSUE_KIND="issue"
run check-cherry-pick-approved.sh
assert_status 0
log_empty

begin_case "skips the sync when RELEASE_BRANCHES is not a valid regular expression"
stub_label_scripts
export RELEASE_BRANCHES='^release-('
mkbase release-1.0
run check-cherry-pick-approved.sh
assert_status 0
assert_out_has "Invalid RELEASE_BRANCHES"
log_lacks "stub"
