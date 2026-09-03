#!/usr/bin/env bash

# check-auto-merge.sh: a PR with both the "lgtm" and "approved" labels and
# every changed area approved is auto-merged, unless a do-not-merge/* or
# "dco-signoff: no" label blocks it.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function stub_merge_scripts() {
    stub approve-status.sh "${1:-0}"
    stub pr-merge.sh
}

begin_case "merges a PR with lgtm and approved when every area is approved"
stub_merge_scripts
mklabels "lgtm" "approved" "kind/bug"
run check-auto-merge.sh
assert_status 0
assert_out_has "Auto-merging"
log_has_line "stub approve-status.sh check"
log_has_line "stub pr-merge.sh"

begin_case "reconciles instead of merging when not every area is approved"
stub_merge_scripts 1
mklabels "lgtm" "approved"
run check-auto-merge.sh
assert_status 0
assert_out_has "Reconciling"
log_has_line "stub approve-status.sh sync"
log_lacks "stub pr-merge.sh"

begin_case "does not merge without the lgtm label"
stub_merge_scripts
mklabels "approved" "kind/bug"
run check-auto-merge.sh
assert_status 0
log_has "view 1 --json labels"
log_lacks "stub"

begin_case "does not merge without the approved label"
stub_merge_scripts
mklabels "lgtm" "kind/bug"
run check-auto-merge.sh
assert_status 0
log_lacks "stub"

begin_case "does not merge an unlabeled PR"
stub_merge_scripts
mklabels
run check-auto-merge.sh
assert_status 0
log_lacks "stub"

begin_case "labels with spaces are compared whole, not word by word"
stub_merge_scripts
mklabels "help wanted" "not approved" "needs lgtm"
run check-auto-merge.sh
assert_status 0
log_lacks "stub"

begin_case "a do-not-merge label skips auto-merge"
stub_merge_scripts
mklabels "lgtm" "approved" "do-not-merge/hold"
run check-auto-merge.sh
assert_status 0
assert_out_has "PR has the 'do-not-merge/hold' label. Skipping auto-merge."
log_lacks "stub"

begin_case "a do-not-merge label with a space is reported whole"
stub_merge_scripts
mklabels "lgtm" "approved" "do-not-merge/hold requested"
run check-auto-merge.sh
assert_status 0
assert_out_has "PR has the 'do-not-merge/hold requested' label. Skipping auto-merge."
log_lacks "stub"

begin_case "the dco-signoff: no label skips auto-merge"
stub_merge_scripts
mklabels "lgtm" "approved" "dco-signoff: no"
run check-auto-merge.sh
assert_status 0
assert_out_has "PR has the 'dco-signoff: no' label. Skipping auto-merge."
log_lacks "stub"

begin_case "the dco-signoff: yes label does not block auto-merge"
stub_merge_scripts
mklabels "lgtm" "approved" "dco-signoff: yes"
run check-auto-merge.sh
assert_status 0
assert_out_has "Auto-merging"
log_has_line "stub pr-merge.sh"

begin_case "does nothing for issues"
stub_merge_scripts
export ISSUE_KIND="issue"
run check-auto-merge.sh
assert_status 0
log_empty
