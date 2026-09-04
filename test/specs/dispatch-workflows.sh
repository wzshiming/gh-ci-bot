#!/usr/bin/env bash

# dispatch-workflows.sh <type> [head-branch]: under the default GITHUB_TOKEN it
# starts the bot's own workflow for the PR (gh workflow run <own file> -f
# number -f type) and every workflow listed in DISPATCH_WORKFLOWS on the head
# branch (`*` discovers those whose on: has pull_request and workflow_dispatch),
# printing one [FAIL] line per run it cannot start and exiting 1 when
# any failed. Any other login does nothing at all.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

WF_REF="wzshiming/example/.github/workflows/ci-bot.yml@refs/heads/master"
FAIL_422="could not create workflow dispatch event: HTTP 422: Workflow does not have 'workflow_dispatch' trigger"

begin_case "does nothing for a token that is not GITHUB_TOKEN"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS="test.yml"
run dispatch-workflows.sh created feature
assert_status 0
assert_out_is ""
log_lacks "workflow run"

begin_case "starts the bot's own run for the PR"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
run dispatch-workflows.sh created cherry-pick/1/release-1.0
assert_status 0
assert_out_lacks "[FAIL]"
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=created"
log_lacks "--ref"

begin_case "starts the listed workflows on the head branch"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS=$'test.yml\n\ne2e.yml'
run dispatch-workflows.sh created cherry-pick/1/release-1.0
assert_status 0
assert_out_lacks "[FAIL]"
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=created"
log_has_line "gh workflow run test.yml -R wzshiming/example --ref cherry-pick/1/release-1.0"
log_has_line "gh workflow run e2e.yml -R wzshiming/example --ref cherry-pick/1/release-1.0"

begin_case "skips the bot's own run outside GitHub Actions"
export BOT_LOGIN="github-actions[bot]"
export DISPATCH_WORKFLOWS="test.yml"
run dispatch-workflows.sh created feature
assert_status 0
assert_out_has "Not running in GitHub Actions"
assert_out_lacks "[FAIL]"
log_lacks "workflow run ci-bot.yml"
log_has_line "gh workflow run test.yml -R wzshiming/example --ref feature"

begin_case "reports workflows that cannot be dispatched"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS=$'test.yml\n\ne2e.yml'
export MOCK_WORKFLOW_RUN_FAIL=1
run dispatch-workflows.sh created cherry-pick/1/release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to start the bot's run for #1: ${FAIL_422}. Add the \`workflow_dispatch\` trigger and the \"PR Dispatched\" step from gh-ci-bot's examples/ci-bot.yml to \`ci-bot.yml\`."
assert_out_has "[FAIL] Failed to start test.yml on cherry-pick/1/release-1.0: ${FAIL_422}"
# The second workflow is still attempted after the first failed.
assert_out_has "[FAIL] Failed to start e2e.yml on cherry-pick/1/release-1.0: ${FAIL_422}"
log_has_line "gh workflow run e2e.yml -R wzshiming/example --ref cherry-pick/1/release-1.0"

begin_case "cannot start the listed workflows for a fork head"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS=$'test.yml\ne2e.yml'
run dispatch-workflows.sh synchronize
assert_status 1
assert_out_has "[FAIL] The head branch of #1 is in a fork, so test.yml, e2e.yml cannot be started with workflow_dispatch; push to the branch or close and reopen the PR to run them."
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=synchronize"
log_lacks "--ref"

begin_case "discovers the workflows that run on pull_request when the list is *"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS="*"
# Only test.yml qualifies: ci-bot.yml is the bot's own, release.yml names
# pull_request outside on:, lint.yml has no trigger, review.yml runs on
# pull_request_target, and e2e.yml is listed but not on the branch.
mkworkflow ci-bot.yml pull_request workflow_dispatch
mkworkflow test.yml push pull_request workflow_dispatch
mkworkflow release.yml push workflow_dispatch
mkworkflow lint.yml pull_request
mkworkflow review.yml pull_request_target workflow_dispatch
mkworkflow e2e.yml
run dispatch-workflows.sh created feature
assert_status 0
assert_out_lacks "[FAIL]"
assert_out_has "Skipping .github/workflows/e2e.yml: not on feature"
log_has_line "gh api --paginate /repos/wzshiming/example/actions/workflows --jq .workflows[] | select(.state == \"active\") | .path | select(startswith(\".github/workflows/\"))"
log_has_line "gh api -H Accept: application/vnd.github.raw+json /repos/wzshiming/example/contents/.github/workflows/test.yml?ref=feature"
log_has_line "gh workflow run test.yml -R wzshiming/example --ref feature"
log_has_line "gh workflow run ci-bot.yml -R wzshiming/example -f number=1 -f type=created"
log_lacks "workflow run ci-bot.yml -R wzshiming/example --ref"
log_lacks "workflow run release.yml"
log_lacks "workflow run lint.yml"
log_lacks "workflow run review.yml"
log_lacks "workflow run e2e.yml"

begin_case "cannot start the discovered workflows for a fork head"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS="*"
run dispatch-workflows.sh synchronize
assert_status 1
assert_out_has "[FAIL] The head branch of #1 is in a fork, so its workflows cannot be started with workflow_dispatch; push to the branch or close and reopen the PR to run them."
log_lacks "actions/workflows"

begin_case "reports a workflow list it cannot fetch"
export BOT_LOGIN="github-actions[bot]"
export GITHUB_WORKFLOW_REF="${WF_REF}"
export DISPATCH_WORKFLOWS="*"
run dispatch-workflows.sh created feature
assert_status 1
assert_out_has "[FAIL] Failed to list the workflows of wzshiming/example:"
log_lacks "--ref"
