#!/usr/bin/env bash

# approve-status.sh: incomplete OWNERS data (OWNERS_LOAD_FAILED, set by
# owners.sh when an OWNERS file or the changed files cannot be fetched)
# grants, revokes and reconciles nothing, while a missing OWNERS file is
# ordinary data. The label scripts are stubbed; comment writes show up in
# the gh log.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function stub_labels() {
    stub add-labels.sh
    stub remove-labels.sh
}

begin_case "/approve replies with an error when the OWNERS data failed to load"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
export OWNERS_LOAD_FAILED=1
run approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Could not load the OWNERS data of this PR because of an API error. Please try again later."
log_empty

begin_case "/approve cancel replies with an error when the OWNERS data failed to load"
stub_labels
export OWNERS_AREA_APPROVERS=". alice"
export OWNERS_LOAD_FAILED=1
run approve-status.sh unapprove alice
assert_status 1
assert_out_has "[FAIL] Could not load the OWNERS data of this PR because of an API error."
log_empty

begin_case "sync leaves the labels and the status comment alone when the OWNERS data failed to load"
stub_labels
export OWNERS_AREA_APPROVERS=""
export OWNERS_LOAD_FAILED=1
run approve-status.sh sync
assert_status 0
assert_out_has "OWNERS data unavailable, skipping the approval sync."
log_empty

begin_case "check fails when the OWNERS data failed to load, even without areas"
stub_labels
export OWNERS_AREA_APPROVERS=""
export OWNERS_LOAD_FAILED=1
run approve-status.sh check
assert_status 1
assert_out_has "OWNERS data unavailable, the approvals cannot be verified."
log_empty

begin_case "check still passes without areas when the OWNERS data loaded"
export OWNERS_AREA_APPROVERS=""
run approve-status.sh check
assert_status 0

begin_case "auto-merge does not merge while the OWNERS data cannot be loaded"
stub_labels
stub pr-merge.sh
mklabels "lgtm" "approved"
mkfiles "README.md"
export MOCK_OWNERS_FAIL=1
run check-auto-merge.sh
assert_status 0
assert_out_has "OWNERS: failed to fetch OWNERS: gh: Internal Server Error (HTTP 500)"
assert_out_has "Reconciling"
assert_out_has "OWNERS data unavailable, skipping the approval sync."
log_lacks "stub"
log_lacks "/issues/1/comments"

begin_case "/approve still works when the repository has no OWNERS files"
stub_labels
export AUTHOR_ASSOCIATION="MEMBER"
export APPROVERS="alice"
export APPROVERS_PLUGINS="label-approve"
export MESSAGE="/approve"
mkfiles "README.md"
run command.sh
assert_status 0
assert_out_lacks "[FAIL]"
assert_out_has "Area '.' approved by alice"
log_has "POST /repos/wzshiming/example/issues/1/comments"
log_has_line "stub add-labels.sh approved"
