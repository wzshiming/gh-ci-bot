#!/usr/bin/env bash

# entrypoint.sh: main() processes the commands in a new issue/PR body
# before syncing the needs-* labels, so a PR opened with /kind in its
# body never keeps a stale do-not-merge/needs-kind label (the bot's own
# labeled event does not retrigger the workflow).

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
