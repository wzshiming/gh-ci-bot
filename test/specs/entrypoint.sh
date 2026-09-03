#!/usr/bin/env bash

# entrypoint.sh: main() processes the commands in a new issue/PR body
# before syncing the needs-* labels, so a PR opened with /kind in its
# body never keeps a stale do-not-merge/needs-kind label (the bot's own
# labeled event does not retrigger the workflow).
#
# It also dispatches the draft-state TYPEs: blunderbuss skips drafts when
# a PR is opened, so ready_for_review must request reviewers, while
# edited and converted_to_draft only sync labels.

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
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "Skipping draft PR"
log_lacks "--add-reviewer"

begin_case "does not request reviewers when a PR is edited"
export TYPE="edited"
export REVIEWERS="carol"
mkwip false "Add a feature"
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_lacks "--add-reviewer"

begin_case "syncs the wip label without requesting reviewers on converted_to_draft"
export TYPE="converted_to_draft"
export REVIEWERS="carol"
mkwip true "Add a feature"
cd "${CASE_DIR}"
run "${ENTRYPOINT}"
assert_status 0
log_has "--add-label do-not-merge/work-in-progress"
log_lacks "--add-reviewer"
