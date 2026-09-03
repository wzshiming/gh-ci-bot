#!/usr/bin/env bash

# bot-login.sh: resolves the bot's login from the BOT_LOGIN override or
# via the API, falling back to github-actions[bot] when the reply is
# missing or empty.

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

begin_case "prints the BOT_LOGIN override without calling the API"
export BOT_LOGIN="my-app[bot]"
run bot-login.sh
assert_status 0
assert_out_is "my-app[bot]"
log_empty

begin_case "prefers the BOT_LOGIN override even when the API call fails"
export BOT_LOGIN="my-app[bot]"
export MOCK_GH_FAIL=1
run bot-login.sh
assert_status 0
assert_out_is "my-app[bot]"
