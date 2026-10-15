#!/usr/bin/env bash

# milestone plugin: /milestone <name> sets the milestone, while prow's
# /milestone clear and /remove-milestone clear it; set-milestone.sh is
# stubbed, so the log shows the milestone each command asked for.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# member <plugins...> grants alice the members tier with the given plugins.
function member() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export MEMBERS_PLUGINS="${*}"
}

begin_case "/milestone <name> sets that milestone"
member milestone
export MESSAGE="/milestone v1.0"
stub set-milestone.sh
run command.sh
assert_status 0
log_has_line "stub set-milestone.sh v1.0"

begin_case "/milestone clear clears the milestone instead of setting one named clear"
member milestone
export MESSAGE="/milestone clear"
stub set-milestone.sh
run command.sh
assert_status 0
log_has_line "stub set-milestone.sh"
log_lacks "stub set-milestone.sh clear"

begin_case "/remove-milestone clears the milestone"
member milestone
export MESSAGE="/remove-milestone"
stub set-milestone.sh
run command.sh
assert_status 0
log_has_line "stub set-milestone.sh"

begin_case "/milestone without a name is refused"
member milestone
export MESSAGE="/milestone"
stub set-milestone.sh
run command.sh
assert_status 0
assert_out_has "[FAIL] Missing required argument: milestone name."
log_lacks "stub set-milestone.sh"
