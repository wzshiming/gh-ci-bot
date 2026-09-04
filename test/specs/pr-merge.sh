#!/usr/bin/env bash

# pr-merge.sh: the do-not-merge, do-not-merge/* and "dco-signoff: no" labels
# block merging, a failed blocking-label query fails closed instead of
# merging blind, and a merge refused for a workflow file under the default
# GITHUB_TOKEN is explained instead of falling back to auto-merge.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

FAIL_MSG='GraphQL: refusing to allow a GitHub App to create or update workflow `.github/workflows/ci-bot.yml` without `workflows` permission (mergePullRequest)'

begin_case "merges when no blocking labels are present"
mklabels "lgtm" "approved"
run pr-merge.sh
assert_status 0
assert_out_has "PR wzshiming/example#1 merge by alice"
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "refuses to merge when a do-not-merge label is present"
mklabels "do-not-merge/hold"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`do-not-merge/hold\`."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "refuses to merge when the bare do-not-merge label is present"
mklabels "lgtm" "approved" "do-not-merge"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`do-not-merge\`."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "a label merely starting with do-not-merge does not block merging"
mklabels "do-not-merge-later"
run pr-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "refuses to merge when the dco-signoff: no label is present"
mklabels "lgtm" "dco-signoff: no"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`dco-signoff: no\`."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "the dco-signoff: yes label does not block merging"
mklabels "dco-signoff: yes"
run pr-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "fails closed when the blocking-label query fails"
export MOCK_GH_FAIL=1
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] Failed to check for blocking labels, not merging."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "explains a merge refused for a workflow file under the default token and does not enable auto-merge"
mklabels "lgtm" "approved"
mkfiles ".github/workflows/ci-bot.yml" "examples/ci-bot.yml"
export MOCK_MERGE_FAIL="${FAIL_MSG}"
export BOT_LOGIN="github-actions[bot]"
run pr-merge.sh
assert_out_has "[FAIL] Failed to merge the PR: ${FAIL_MSG}"
assert_out_has "[FAIL] This change touches \`.github/workflows/ci-bot.yml\`, which the default \`GITHUB_TOKEN\` cannot merge or push"
log_has_line "gh pr -R wzshiming/example merge 1 --merge"
log_lacks "--auto"
log_has "/pulls/1/files"

begin_case "falls back to auto-merge when the failed merge touched no workflow file"
mklabels "lgtm" "approved"
mkfiles "README.md"
export MOCK_MERGE_FAIL="${FAIL_MSG}"
export BOT_LOGIN="github-actions[bot]"
run pr-merge.sh
assert_out_has "[FAIL] Failed to merge the PR: ${FAIL_MSG}"
assert_out_lacks "[FAIL] This change touches"
log_has_line "gh pr -R wzshiming/example merge 1 --auto --merge"

begin_case "falls back to auto-merge for a token that is not GITHUB_TOKEN"
mklabels "lgtm" "approved"
mkfiles ".github/workflows/ci-bot.yml"
export MOCK_MERGE_FAIL="${FAIL_MSG}"
export BOT_LOGIN="my-app[bot]"
run pr-merge.sh
assert_out_lacks "[FAIL] This change touches"
log_has_line "gh pr -R wzshiming/example merge 1 --auto --merge"

begin_case "falls back to auto-merge when the changed files are unknown"
mklabels "lgtm" "approved"
export MOCK_MERGE_FAIL="${FAIL_MSG}"
export BOT_LOGIN="github-actions[bot]"
run pr-merge.sh
assert_out_lacks "[FAIL] This change touches"
log_has_line "gh pr -R wzshiming/example merge 1 --auto --merge"
