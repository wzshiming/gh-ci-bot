#!/usr/bin/env bash

# lifecycle plugin: /close and /reopen act on the issue or PR, and prow's
# /close not-planned closes an issue with the "not planned" reason but is
# refused on PRs, which GitHub cannot close as not planned.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# member <plugins...> grants alice the members tier with the given plugins.
function member() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export MEMBERS_PLUGINS="${*}"
}

begin_case "/close closes the issue"
member lifecycle
export ISSUE_KIND="issue"
export MESSAGE="/close"
run command.sh
assert_status 0
log_has_line "gh issue -R wzshiming/example close 1"

begin_case "/close not-planned closes the issue as not planned"
member lifecycle
export ISSUE_KIND="issue"
export MESSAGE="/close not-planned"
run command.sh
assert_status 0
log_has_line "gh issue -R wzshiming/example close 1 --reason not planned"

# On PRs command.sh also logs the OWNERS lookup, so only close calls are ruled out.
begin_case "/close not-planned on a PR is refused without closing it"
member lifecycle
export MESSAGE="/close not-planned"
run command.sh
assert_status 0
assert_out_has '[FAIL] PRs cannot be closed as "Not Planned".'
log_lacks "close"

begin_case "/close closes the PR"
member lifecycle
export MESSAGE="/close"
run command.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example close 1"

begin_case "/reopen reopens the issue"
member lifecycle
export ISSUE_KIND="issue"
export MESSAGE="/reopen"
run command.sh
assert_status 0
log_has_line "gh issue -R wzshiming/example reopen 1"
