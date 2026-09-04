#!/usr/bin/env bash

# explain-workflows-permission.sh: reads changed paths from stdin and prints
# a [FAIL] hint when one is under .github/workflows/ and the bot login is
# github-actions[bot]; otherwise it prints nothing and exits 1.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "explains the workflows permission when the default token touches a workflow file"
export BOT_LOGIN="github-actions[bot]"
run explain-workflows-permission.sh <<<$'.github/workflows/ci-bot.yml\nREADME.md'
assert_status 0
assert_out_is "[FAIL] This change touches \`.github/workflows/ci-bot.yml\`, which the default \`GITHUB_TOKEN\` cannot merge or push because it cannot be granted the \`workflows\` permission. Run the bot with a PAT that has the \`workflow\` scope or a GitHub App token with \`workflows: write\` as \`GH_TOKEN\`, or do it manually."

begin_case "lists every workflow file touched"
export BOT_LOGIN="github-actions[bot]"
run explain-workflows-permission.sh <<<$'.github/workflows/ci-bot.yml\n.github/OWNERS\n.github/workflows/test.yml'
assert_status 0
assert_out_has "touches \`.github/workflows/ci-bot.yml\`, \`.github/workflows/test.yml\`, which"

begin_case "stays silent when no workflow file is touched"
export BOT_LOGIN="github-actions[bot]"
run explain-workflows-permission.sh <<<$'.github/OWNERS\nREADME.md'
assert_status 1
assert_out_is ""

begin_case "does not resolve the login when no workflow file is touched"
run explain-workflows-permission.sh <<<$'.github/OWNERS\nREADME.md'
assert_status 1
assert_out_is ""
log_empty

begin_case "stays silent for a token that is not the default GITHUB_TOKEN"
export BOT_LOGIN="my-app[bot]"
run explain-workflows-permission.sh <<<".github/workflows/ci-bot.yml"
assert_status 1
assert_out_is ""

begin_case "stays silent when the login resolved via the API is not github-actions[bot]"
run explain-workflows-permission.sh <<<".github/workflows/ci-bot.yml"
assert_status 1
assert_out_is ""
log_has_line "gh api /user"
