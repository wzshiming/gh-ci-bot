#!/usr/bin/env bash

# /cherry-pick-approved: maintainers unblock a PR into a release branch by
# adding cherry-pick-approved and dropping do-not-merge/cherry-pick-not-approved;
# `cancel` removes the approval again. Labels only, no comments.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

PLUGIN="${PLUGINS_DIR}/cherry-pick-approved/cherry-pick-approved.plugin.sh"
APPROVED_LABEL="cherry-pick-approved"
UNAPPROVED_LABEL="do-not-merge/cherry-pick-not-approved"

begin_case "is only available on pull requests"
export ISSUE_KIND="issue"
stub add-labels.sh
stub remove-labels.sh
run "${PLUGIN}"
assert_status 1
assert_out_has "[FAIL] This command is only available on pull requests, not on issues."
log_empty

begin_case "approves a blocked PR"
stub add-labels.sh
stub remove-labels.sh
mklabels "${UNAPPROVED_LABEL}"
run "${PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${APPROVED_LABEL}"
log_has_line "stub remove-labels.sh ${UNAPPROVED_LABEL}"

begin_case "leaves an already approved PR alone"
stub add-labels.sh
stub remove-labels.sh
mklabels "${APPROVED_LABEL}" "lgtm"
run "${PLUGIN}"
assert_status 0
log_lacks "stub add-labels.sh"
log_lacks "stub remove-labels.sh"

begin_case "cancel removes the approval"
stub add-labels.sh
stub remove-labels.sh
mklabels "${APPROVED_LABEL}"
run "${PLUGIN}" cancel
assert_status 0
log_has_line "stub remove-labels.sh ${APPROVED_LABEL}"
log_lacks "stub add-labels.sh"

begin_case "cancel does nothing on an unapproved PR"
stub add-labels.sh
stub remove-labels.sh
mklabels "lgtm"
run "${PLUGIN}" cancel
assert_status 0
log_lacks "stub remove-labels.sh"

begin_case "never mutates labels when the PR query fails"
export MOCK_GH_FAIL=1
stub add-labels.sh
stub remove-labels.sh
run "${PLUGIN}"
assert_status 1
assert_out_has "[FAIL] Failed to get the pull request."
log_lacks "stub "
