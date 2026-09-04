#!/usr/bin/env bash

# entrypoint.sh: main() processes the commands in a new issue/PR body
# before syncing the needs-* labels, so a PR opened with /kind in its
# body never keeps a stale do-not-merge/needs-kind label (the bot's own
# labeled event does not retrigger the workflow).
#
# For the same reason the matching-labels sync tails every branch of
# main(), ahead of the auto-merge check: a push or an edit changes labels
# too (owners-label, wip, size, release-note), and the labels the run
# applies itself start no run of their own. The cherry-pick approval sync
# runs right before it, so a /base or /cherry-pick-approved command the
# run just processed is reflected in the same run.
#
# It also dispatches the draft-state TYPEs: blunderbuss skips drafts when
# a PR is opened, so ready_for_review must request reviewers, while
# edited and converted_to_draft only sync labels.
#
# reopened runs the same full sync as a push: a closed PR gets no
# synchronize events, so its labels may be stale, and a PR whose opened
# event never started a run (one created with GITHUB_TOKEN) has none.
# Unlike a push it keeps the lgtm label: the reviewed code is unchanged.
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

begin_case "a reopen runs the full push sync but keeps the lgtm label"
export TYPE="reopened"
export RELEASE_NOTE_REQUIRED=1
export DCO_REQUIRED=1
export BLOCK_MERGE_COMMITS=1
export PR_REQUIRE_MATCHING_LABELS="needs-kind ^kind/"
mkpr ""
mkwip false "Add a feature"
mksize 1 0
mkcommits "1:Add a feature"
mklabels lgtm
mkrepolabels
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR reopened, re-syncing labels"
log_lacks "--remove-label lgtm"
log_has "--add-label do-not-merge/release-note-label-needed"
log_has "--add-label dco-signoff: no"
log_has "--add-label size/XS"
log_has "/pulls/1/commits"
log_has "--add-label needs-kind"
log_lacks "--add-reviewer"

begin_case "a reopen on a qualifying PR merges it"
export TYPE="reopened"
mkwip false "Add a feature"
mksize 1 0
mklabels lgtm approved kind/feature
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Auto-merging."
log_has "merge 1 --merge"

begin_case "an unlabeled event evaluates auto-merge and still respects blockers"
export TYPE="unlabeled"
mklabels lgtm approved kind/feature do-not-merge/hold
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR has the 'do-not-merge/hold' label. Skipping auto-merge."
log_lacks " merge 1"

begin_case "a labeled event removes the cherry-pick block once the PR is approved"
export TYPE="labeled"
export RELEASE_BRANCHES='^release-'
mkbase release-1.0 cherry-pick-approved do-not-merge/cherry-pick-not-approved
mklabels cherry-pick-approved do-not-merge/cherry-pick-not-approved
run "${ENTRYPOINT}"
assert_status 0
log_has "--remove-label do-not-merge/cherry-pick-not-approved"
log_lacks " merge 1"

begin_case "full stack: an unlabeled event on a qualifying PR merges it"
export TYPE="unlabeled"
mklabels lgtm approved kind/feature
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Auto-merging."
log_has "merge 1 --merge"

begin_case "a /kind comment runs the auto-merge check after the matching-labels sync"
export TYPE="comment"
export PLUGINS="label-kind"
export MESSAGE="/kind feature"
export PR_REQUIRE_MATCHING_LABELS="needs-kind ^kind/"
mklabels lgtm approved kind/feature needs-kind
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
