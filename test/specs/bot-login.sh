#!/usr/bin/env bash

# bot-login.sh: resolves the bot's login via the API, falling back to
# github-actions[bot] when the reply is missing or empty; BOT_LOGIN
# overrides both (GitHub App installation tokens cannot call /user).

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "prints the login returned by the API"
run bot-login.sh
assert_status 0
assert_out_is "mock-bot"

begin_case "falls back to github-actions[bot] when the API call fails"
export MOCK_GH_FAIL=1
run bot-login.sh
assert_status 0
assert_out_has "github-actions[bot]"
assert_out_has "set BOT_LOGIN"

begin_case "BOT_LOGIN overrides the API lookup"
export BOT_LOGIN="my-app[bot]"
run bot-login.sh
assert_status 0
assert_out_is "my-app[bot]"
log_empty

begin_case "BOT_LOGIN wins even when the API call would fail"
export BOT_LOGIN="my-app[bot]"
export MOCK_GH_FAIL=1
run bot-login.sh
assert_status 0
assert_out_is "my-app[bot]"
