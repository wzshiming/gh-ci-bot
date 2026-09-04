#!/usr/bin/env bash

# rebase plugin: rebases the PR's branch with gh pr update-branch and then
# starts the runs the default GITHUB_TOKEN withholds from that push (the bot's
# own workflow, and DISPATCH_WORKFLOWS on the head branch unless it is in a
# fork); a failed fetch or rebase is reported with [FAIL] and starts nothing.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

REBASE="${PLUGINS_DIR}/rebase/rebase.plugin.sh"
WF_REF="wzshiming/example/.github/workflows/ci-bot.yml@refs/heads/master"

begin_case "refuses to run on an issue"
export ISSUE_KIND=issue
run "${REBASE}"
assert_status 1
assert_out_has "[FAIL] This command is only available on pull requests, not on issues."
log_lacks "pr -R"

begin_case "rebases the branch and starts the runs GITHUB_TOKEN withholds"
mkhead feature false
export BOT_LOGIN="github-actions[bot]" GITHUB_WORKFLOW_REF="${WF_REF}" DISPATCH_WORKFLOWS="test.yml"
run "${REBASE}"
assert_status 0
log_has_line "gh pr -R wzshiming/example update-branch 1 --rebase"
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=synchronize"
log_has_line "gh workflow run test.yml -R wzshiming/example --ref feature"
log_before "update-branch" "workflow run"
assert_out_lacks "[FAIL]"

begin_case "cannot start the listed workflows for a PR from a fork"
mkhead feature true
export BOT_LOGIN="github-actions[bot]" GITHUB_WORKFLOW_REF="${WF_REF}" DISPATCH_WORKFLOWS="test.yml"
run "${REBASE}"
assert_status 1
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=synchronize"
assert_out_has "[FAIL] The head branch of #1 is in a fork, so test.yml cannot be started with workflow_dispatch; push to the branch or close and reopen the PR to run them."
log_lacks "--ref"

begin_case "reports a failed rebase and starts nothing"
mkhead feature false
export BOT_LOGIN="github-actions[bot]" GITHUB_WORKFLOW_REF="${WF_REF}"
export MOCK_UPDATE_BRANCH_FAIL="GraphQL: merge conflict between base and head (updatePullRequestBranch)"
run "${REBASE}"
assert_status 1
assert_out_has "[FAIL] Failed to rebase the branch. The branch may have conflicts that need to be resolved manually."
log_lacks "workflow run"

begin_case "starts no runs for a token that fires the real events"
mkhead feature false
export GITHUB_WORKFLOW_REF="${WF_REF}" DISPATCH_WORKFLOWS="test.yml"
run "${REBASE}"
assert_status 0
log_has_line "gh pr -R wzshiming/example update-branch 1 --rebase"
log_lacks "workflow run"

begin_case "fails closed when the pull request cannot be fetched"
export MOCK_GH_FAIL=1
run "${REBASE}"
assert_status 1
assert_out_has "[FAIL] Failed to get the pull request."
log_lacks "update-branch"
