#!/usr/bin/env bash

# approve-status.sh: the approval state lives in one bot comment. A comment
# that cannot be listed or read must stop the command: passed through as an
# empty state it would be rewritten without the approvals it holds. The
# label scripts are stubbed; comment reads and writes show up in the gh log.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

STATE_A=$'<!-- ci-bot-approve-status\n. alice\nbin\n-->\n[APPROVALNOTIFIER] A'

function stub_labels() {
    stub add-labels.sh
    stub remove-labels.sh
}

begin_case "sync updates the status comment in place"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments carol "${STATE_A}" mock-bot "${STATE_A}"
run approve-status.sh sync
assert_status 0
log_has "PATCH /repos/wzshiming/example/issues/comments/2 -f body=<!-- ci-bot-approve-status"
log_has ". alice"
log_lacks "-X POST"
log_has_line "stub remove-labels.sh approved"

begin_case "no status comment yet creates one"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
run approve-status.sh sync
assert_status 0
log_has "POST /repos/wzshiming/example/issues/1/comments"
log_lacks "PATCH"

begin_case "/approve records the approval in the status comment"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot $'<!-- ci-bot-approve-status\n. bob\nbin\n-->\nA'
run approve-status.sh approve alice
assert_status 0
assert_out_has "Area '.' approved by alice"
assert_out_has "Area 'bin' approved by alice"
log_has "PATCH /repos/wzshiming/example/issues/comments/1"
log_has ". bob alice"
log_has_line "stub add-labels.sh approved"

begin_case "a status comment that cannot be read stops the sync"
stub_labels
export OWNERS_AREA_APPROVERS=$'. alice bob\nbin alice'
mkissuecomments mock-bot "${STATE_A}"
export MOCK_COMMENT_FAIL=1
run approve-status.sh sync
assert_status 1
assert_out_has "Could not read the approval status, skipping the approval sync."
log_lacks "PATCH"
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

begin_case "/approve cancel replies with an error when the status comment cannot be read"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
mkissuecomments mock-bot "${STATE_A}"
export MOCK_COMMENT_FAIL=1
run approve-status.sh unapprove alice
assert_status 1
assert_out_has "[FAIL] Could not read the approval status of this PR. Please try again later."
log_lacks "PATCH"
log_lacks "stub"

begin_case "check fails when the status comment cannot be read"
# Read as an empty state, the revoked self-approval below would come back.
export AUTHOR="bob"
export OWNERS_AREA_APPROVERS=". bob"
mkissuecomments mock-bot $'<!-- ci-bot-approve-status\n.\n-->\nA'
export MOCK_COMMENT_FAIL=1
run approve-status.sh check
assert_status 1
