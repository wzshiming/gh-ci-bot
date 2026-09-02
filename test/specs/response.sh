#!/usr/bin/env bash

# response.sh: failed commands are reported back in a comment, with the
# token masked, and the reply is not lost when GH_TOKEN is unset.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# run_response runs response.sh from the case dir, where it writes its
# ci-bot.log.
function run_response() {
    run bash -c 'cd "$1" && response.sh' bash "${CASE_DIR}"
}

begin_case "replies with the failure of an unknown command"
export MESSAGE="/nonexistent"
run_response
assert_status 0
log_has "comment 1 --body @alice"
log_has ":x: Unknown command \`/nonexistent\`."

begin_case "does not comment when no command failed"
export MESSAGE="hello"
run_response
assert_status 0
log_lacks "comment 1"

begin_case "still replies when GH_TOKEN is unset"
unset GH_TOKEN
export MESSAGE="/nonexistent"
run_response
assert_status 0
log_has "comment 1 --body @alice"
log_has ":x: Unknown command \`/nonexistent\`."
