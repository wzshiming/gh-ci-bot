#!/usr/bin/env bash

# entrypoint.sh: main() processes the commands in a new issue/PR body
# before syncing the needs-* labels, so a PR opened with /kind in its
# body never keeps a stale do-not-merge/needs-kind label (the bot's own
# labeled event does not retrigger the workflow).
#
# For the same reason the matching-labels sync tails every branch of
# main(), ahead of the auto-merge check: a push or an edit changes labels
# too (owners-label, wip, size, release-note), and the labels the run
# applies itself start no run of their own.
#
# It also dispatches the draft-state TYPEs: blunderbuss skips drafts when
# a PR is opened, so ready_for_review must request reviewers, while
# edited and converted_to_draft only sync labels.
#
# Auto-merge is evaluated once, at the end of every PR event
# (sync_auto_merge), so a qualifying PR is merged no matter which
# command, sync or UI action removed its last blocker; issue events
# never run the check.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "processes body commands before the matching-labels check on creation"
export TYPE="created"
export PLUGINS="label-kind"
export MESSAGE="/kind feature"
mkpr "/kind feature"
mkwip false "Add a feature"
mksize 1 0
mklabels
mkrepolabels "kind/feature" "needs-kind"
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label kind/feature"
# The label fixture is static, so the matching-labels check still sees no
# kind/* label and fires; only the order below matters.
log_has "--add-label needs-kind"
log_before "--add-label kind/feature" "--add-label needs-kind"

begin_case "processes comment commands before the matching-labels check"
export TYPE="comment"
export PLUGINS="label-kind"
export MESSAGE="/kind feature"
mkpr "/kind feature"
mkwip false "Add a feature"
mksize 1 0
mklabels
mkrepolabels "kind/feature" "needs-kind"
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label kind/feature"
log_has "--add-label needs-kind"
log_before "--add-label kind/feature" "--add-label needs-kind"

begin_case "requests reviewers when a draft PR becomes ready for review"
export TYPE="ready_for_review"
export REVIEWERS="carol"
mkwip false "Add a feature" "do-not-merge/work-in-progress"
mklabels
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--remove-label do-not-merge/work-in-progress"
assert_out_has "Auto-requesting reviews from carol."
log_has "edit 1 --add-reviewer carol"

begin_case "still skips reviewer requests while the PR is a draft"
export TYPE="ready_for_review"
export REVIEWERS="carol"
mkwip true "Add a feature"
mklabels
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Skipping draft PR"
log_lacks "--add-reviewer"

begin_case "does not request reviewers when a PR is edited"
export TYPE="edited"
export REVIEWERS="carol"
mkwip false "Add a feature"
mklabels
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_lacks "--add-reviewer"

begin_case "syncs the wip label without requesting reviewers on converted_to_draft"
export TYPE="converted_to_draft"
export REVIEWERS="carol"
mkwip true "Add a feature"
mklabels
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label do-not-merge/work-in-progress"
log_lacks "--add-reviewer"

begin_case "a push re-syncs the matching labels after applying the owners labels"
export TYPE="synchronize"
export PR_REQUIRE_MATCHING_LABELS="needs-sig ^sig/"
mkwip false "Add a feature"
mksize 1 0
mkfiles "pkg/foo/x.go"
mkowners $'approvers:\n  - carol\nlabels:\n  - sig/foo'
# The label fixture is the state right after apply_owners_labels added
# sig/foo: the bot's own labeled event starts no run, so the same run
# must drop the now-satisfied needs-sig.
mklabels needs-sig sig/foo
mkrepolabels needs-sig sig/foo
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label sig/foo"
log_has "--remove-label needs-sig"
log_before "--add-label sig/foo" "--remove-label needs-sig"

begin_case "an edit re-syncs the matching labels"
export TYPE="edited"
mkwip false "Add a feature"
mklabels kind/feature needs-kind
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--remove-label needs-kind"

begin_case "an unlabeled event evaluates auto-merge and still respects blockers"
export TYPE="unlabeled"
mklabels lgtm approved kind/feature do-not-merge/hold
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR has the 'do-not-merge/hold' label. Skipping auto-merge."
log_lacks " merge 1"

begin_case "full stack: an unlabeled event on a qualifying PR merges it"
export TYPE="unlabeled"
mklabels lgtm approved kind/feature
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 0
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Auto-merging."
log_has "merge 1 --merge"

begin_case "full stack: a stale PR is not merged before it is retested"
export TYPE="unlabeled"
export AUTO_MERGE_UPDATE_BRANCH="true"
mklabels lgtm approved kind/feature
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 3
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Skipping auto-merge."
assert_out_has "Updating the branch to retest against the latest base."
log_has "update-branch 1"
log_lacks " merge 1"

begin_case "a /kind comment runs the auto-merge check after the matching-labels sync"
export TYPE="comment"
export PLUGINS="label-kind"
export MESSAGE="/kind feature"
export PR_REQUIRE_MATCHING_LABELS="needs-kind ^kind/"
mklabels lgtm approved kind/feature needs-kind
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 0
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label kind/feature"
log_before "--add-label kind/feature" "--remove-label needs-kind"
log_before "--remove-label needs-kind" " merge 1 --merge"
assert_out_has "Auto-merging."

begin_case "an issue label event never evaluates auto-merge"
export TYPE="labeled"
export ISSUE_KIND="issue"
mklabels lgtm approved kind/feature
run "${ENTRYPOINT}"
assert_status 0
log_has "issue -R wzshiming/example view 1 --json labels"
log_lacks "gh pr"
assert_out_lacks "Auto-merging."
assert_out_lacks "Skipping auto-merge."

begin_case "a push by someone else still removes the lgtm label"
export TYPE="synchronize"
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a feature"
mksize 1 0
mklabels lgtm kind/feature
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR synchronized, removing lgtm label"
log_has "--remove-label lgtm"

begin_case "a push by the bot itself keeps the lgtm label"
export TYPE="synchronize"
export LOGIN="mock-bot"
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a feature"
mksize 1 0
mklabels lgtm kind/feature
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR synchronized by the bot itself, keeping the lgtm label"
log_lacks "--remove-label lgtm"

begin_case "a scheduled sync reconciles the merge pool without an issue number"
export TYPE="schedule"
export ISSUE_NUMBER=""
mkpool
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Scheduled sync, reconciling the merge pool"
assert_out_has "The merge pool is empty."
log_lacks "view"

begin_case "full stack: a scheduled sync merges a green pool PR"
export TYPE="schedule"
export ISSUE_NUMBER=""
mkpool 3
mklabels lgtm approved kind/feature
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 0
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Evaluating merge pool PR #3"
assert_out_has "Auto-merging."
log_has "view 3 --json labels"
log_has "merge 3 --merge"
