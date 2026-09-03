#!/usr/bin/env bash

# check-auto-merge.sh: a PR with both the "lgtm" and "approved" labels and
# every changed area approved is auto-merged, unless a do-not-merge/*
# label blocks it. Right before merging, the PR state is re-validated the
# way tide reconciles its pool: conflicts, a head behind the base branch
# and non-green checks all block the merge, and a stale head is only
# updated to retest against the latest base when AUTO_MERGE_UPDATE_BRANCH
# is set. The bot's own workflow is excluded from the checks, or every
# pull_request_target run would deadlock on its own in-progress check.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function stub_merge_scripts() {
    stub approve-status.sh "${1:-0}"
    stub pr-merge.sh
}

begin_case "merges a PR with lgtm and approved when every area is approved"
stub_merge_scripts
mklabels "lgtm" "approved" "kind/bug"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 0
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

begin_case "does not merge a PR with conflicts"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate CONFLICTING
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "PR has conflicts with the base branch. Skipping auto-merge."
log_lacks "stub pr-merge.sh"

begin_case "does not merge while GitHub is still computing mergeability"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate UNKNOWN
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "PR mergeability is still being computed by GitHub. Skipping auto-merge."
log_lacks "stub pr-merge.sh"

begin_case "fails closed when the merge state query fails"
stub_merge_scripts
mklabels "lgtm" "approved"
run check-auto-merge.sh
assert_status 0
assert_out_has "Failed to fetch the PR merge state. Skipping auto-merge."
log_lacks "stub pr-merge.sh"

begin_case "does not merge a PR that is behind its base branch"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 2
run check-auto-merge.sh
assert_status 0
assert_out_has "PR is behind the base branch by 2 commit(s), so its checks did not run against the latest base. Skipping auto-merge."
log_lacks "update-branch"
log_lacks "stub pr-merge.sh"

begin_case "a stale PR is updated to retest when AUTO_MERGE_UPDATE_BRANCH is set"
stub_merge_scripts
export AUTO_MERGE_UPDATE_BRANCH="true"
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 1
run check-auto-merge.sh
assert_status 0
assert_out_has "Updating the branch to retest against the latest base."
log_has_line "gh pr -R wzshiming/example update-branch 1"
log_lacks "stub pr-merge.sh"

begin_case "fails closed when the base-freshness compare fails"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
run check-auto-merge.sh
assert_status 0
assert_out_has "Failed to compare the PR with its base branch. Skipping auto-merge."
log_lacks "stub pr-merge.sh"

begin_case "does not merge while a check is failing"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS" "CI,lint,COMPLETED,FAILURE"
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "Some checks on the PR are failing. Skipping auto-merge."
log_lacks "stub pr-merge.sh"

begin_case "does not merge while a check is still pending"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,IN_PROGRESS,"
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "Some checks on the PR are still pending. Skipping auto-merge until they finish."
log_lacks "stub pr-merge.sh"

begin_case "the bot's own in-progress workflow run does not deadlock the merge"
stub_merge_scripts
export GITHUB_WORKFLOW="CI Bot"
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI Bot,bot,IN_PROGRESS," "CI,test,COMPLETED,SUCCESS"
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "Auto-merging"
log_has_line "stub pr-merge.sh"

begin_case "commit statuses gate the merge like check runs"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS" "status,external-ci,PENDING"
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "Some checks on the PR are still pending. Skipping auto-merge until they finish."
log_lacks "stub pr-merge.sh"

begin_case "a successful commit status does not block the merge"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "status,external-ci,SUCCESS"
mkbehind 0
run check-auto-merge.sh
assert_status 0
assert_out_has "Auto-merging"
log_has_line "stub pr-merge.sh"

begin_case "a PR with no checks at all merges"
stub_merge_scripts
mklabels "lgtm" "approved"
mkmergestate MERGEABLE
mkbehind 0
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
