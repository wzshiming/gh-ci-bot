#!/usr/bin/env bash

# approve-status.sh: the approval state lives in one bot comment. Two
# overlapping runs can both find none and both create one; the next update
# merges the approvals of such duplicates into the oldest comment and
# deletes the others, so no recorded approval is lost. The label scripts
# are stubbed; comment reads and writes show up in the gh log.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

STATE_A=$'<!-- ci-bot-approve-status\n. alice\nbin\n-->\n[APPROVALNOTIFIER] A'
STATE_B=$'<!-- ci-bot-approve-status\n. bob\nbin alice\n-->\n[APPROVALNOTIFIER] B'

function stub_labels() {
    stub add-labels.sh
    stub remove-labels.sh
}

begin_case "sync merges duplicate status comments into the oldest and deletes the others"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot "${STATE_A}" carol "${STATE_A}" mock-bot "${STATE_B}"
run approve-status.sh sync
assert_status 0
log_has "PATCH /repos/wzshiming/example/issues/comments/1 -f body=<!-- ci-bot-approve-status"
log_has ". alice bob"
log_has "bin alice"
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/issues/comments/3"
log_lacks "DELETE /repos/wzshiming/example/issues/comments/2"
log_lacks "-X POST"
log_has_line "stub add-labels.sh approved"

begin_case "a single status comment is updated in place"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot "${STATE_A}"
run approve-status.sh sync
assert_status 0
log_has "PATCH /repos/wzshiming/example/issues/comments/1"
log_lacks "DELETE"
log_lacks "-X POST"
log_has_line "stub remove-labels.sh approved"

begin_case "no status comment yet creates one"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
run approve-status.sh sync
assert_status 0
log_has "POST /repos/wzshiming/example/issues/1/comments"
log_lacks "PATCH"
log_lacks "DELETE"

begin_case "check counts the approvals recorded in a duplicate without touching the comments"
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot "${STATE_A}" mock-bot "${STATE_B}"
run approve-status.sh check
assert_status 0
log_lacks "PATCH"
log_lacks "DELETE"
log_lacks "POST"

begin_case "/approve records the approval in the oldest comment and drops the duplicate"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot $'<!-- ci-bot-approve-status\n. bob\nbin\n-->\nA' mock-bot $'<!-- ci-bot-approve-status\n.\nbin\n-->\nB'
run approve-status.sh approve alice
assert_status 0
assert_out_has "Area '.' approved by alice"
assert_out_has "Area 'bin' approved by alice"
log_has "PATCH /repos/wzshiming/example/issues/comments/1"
log_has ". bob alice"
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/issues/comments/2"
log_has_line "stub add-labels.sh approved"

# An unreadable comment would pass for an empty state: the update would
# overwrite the approvals it holds and delete it if it is a duplicate.
begin_case "a status comment that cannot be read stops the sync"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot "${STATE_A}" mock-bot "${STATE_B}"
export MOCK_COMMENT_FAIL=1
run approve-status.sh sync
assert_status 1
assert_out_has "Could not read the approval status, skipping the approval sync."
log_lacks "PATCH"
log_lacks "DELETE"
log_lacks "POST"
log_lacks "stub"

begin_case "/approve replies with an error when the comments cannot be listed"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
export MOCK_GH_FAIL=1
run approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Could not read the approval status of this PR. Please try again later."
log_lacks "POST"
log_lacks "stub"

begin_case "check fails when a status comment cannot be read"
export OWNERS_AREA_APPROVERS=". alice"
mkissuecomments mock-bot "${STATE_A}"
export MOCK_COMMENT_FAIL=1
run approve-status.sh check
assert_status 1
