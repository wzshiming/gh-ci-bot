#!/usr/bin/env bash

# disable-auto-merge.sh: a merge that `/merge` queued through GitHub's
# auto-merge is disarmed once a do-not-merge/* label lands on the PR, both
# when the bot adds the label (add-labels.sh) and when it is added through
# the GitHub UI (entrypoint.sh, TYPE=labeled).

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "does nothing for issues"
export ISSUE_KIND="issue"
run disable-auto-merge.sh
assert_status 0
log_empty

begin_case "does nothing when no auto-merge is queued"
mkautomerge false "do-not-merge/hold"
run disable-auto-merge.sh
assert_status 0
log_has "view 1 --json autoMergeRequest,labels"
log_lacks "--disable-auto"

begin_case "does nothing when queued without a do-not-merge label"
mkautomerge true "lgtm" "approved"
run disable-auto-merge.sh
assert_status 0
log_has "view 1 --json autoMergeRequest,labels"
log_lacks "--disable-auto"

begin_case "disables a queued auto-merge when a do-not-merge label is present"
mkautomerge true "do-not-merge/hold" "lgtm"
run disable-auto-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --disable-auto"
assert_out_has "do-not-merge/hold"
assert_out_lacks "[FAIL]"

begin_case "names every blocking label"
mkautomerge true "do-not-merge/hold" "do-not-merge/work-in-progress"
run disable-auto-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --disable-auto"
assert_out_has "do-not-merge/hold"
assert_out_has "do-not-merge/work-in-progress"

begin_case "replies [FAIL] when the auto-merge query fails"
export MOCK_GH_FAIL=1
run disable-auto-merge.sh
assert_status 1
assert_out_has "[FAIL] Failed to check whether auto-merge is enabled"
log_lacks "--disable-auto"

begin_case "full stack: adding a do-not-merge label disables the queued auto-merge"
mkautomerge true "do-not-merge/hold"
run add-labels.sh do-not-merge/hold
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label do-not-merge/hold"
log_has_line "gh pr -R wzshiming/example merge 1 --disable-auto"
log_before "--add-label do-not-merge/hold" "--disable-auto"

begin_case "adding a non-blocking label never queries auto-merge"
run add-labels.sh kind/bug
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label kind/bug"
log_lacks "autoMergeRequest"

# entrypoint.sh puts the real bin/ ahead of the stub dir on PATH, so these
# run the full stack and prove the order through the gh queries.
begin_case "entrypoint: a labeled event syncs auto-merge after the needs-* labels"
mklabels "kind/bug" "do-not-merge/hold"
mkautomerge true "do-not-merge/hold" "kind/bug"
export TYPE="labeled"
run "${ENTRYPOINT}"
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --disable-auto"
log_before "view 1 --json labels" "view 1 --json autoMergeRequest,labels"

begin_case "entrypoint: an unlabeled event does not touch auto-merge"
mklabels "kind/bug"
mkautomerge true "do-not-merge/hold"
export TYPE="unlabeled"
run "${ENTRYPOINT}"
assert_status 0
log_has "view 1 --json labels"
log_lacks "autoMergeRequest"

begin_case "entrypoint: a labeled event on an issue does not touch auto-merge"
mklabels "kind/bug"
mkautomerge true "do-not-merge/hold"
export TYPE="labeled"
export ISSUE_KIND="issue"
run "${ENTRYPOINT}"
assert_status 0
log_has "gh issue -R wzshiming/example view 1 --json labels"
log_lacks "autoMergeRequest"
