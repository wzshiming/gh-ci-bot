#!/usr/bin/env bash

# transfer-issue plugin, through prow's /transfer spelling: moves the issue
# to another repository of the organization, and is refused on PRs.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# member <plugins...> grants alice the members tier with the given plugins.
function member() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export MEMBERS_PLUGINS="${*}"
}

begin_case "/transfer <repo> transfers the issue like /transfer-issue"
member transfer-issue
export ISSUE_KIND="issue"
export MESSAGE="/transfer other"
run command.sh
assert_status 0
log_has_line "gh issue transfer -R wzshiming/example 1 wzshiming/other"

begin_case "/transfer on a PR is refused like /transfer-issue"
member transfer-issue
export MESSAGE="/transfer other"
run command.sh
assert_status 0
assert_out_has "[FAIL] This command is only available on issues, not on pull requests."
log_lacks "issue transfer"

begin_case "/transfer-issue <repo> transfers the issue through the bin script"
member transfer-issue
export ISSUE_KIND="issue"
export MESSAGE="/transfer-issue other"
run command.sh
assert_status 0
log_has_line "gh issue transfer -R wzshiming/example 1 wzshiming/other"
