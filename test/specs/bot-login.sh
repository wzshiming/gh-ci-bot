#!/usr/bin/env bash

# bot-login.sh: resolves the bot's login via the API, falling back to
# github-actions[bot] when the reply is missing or empty.

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
