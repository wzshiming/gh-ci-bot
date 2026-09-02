#!/usr/bin/env bash

# command.sh: /command dispatch through the permission tiers, exercised
# with the hold, label-lgtm and assign plugins.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

HOLD_LABEL="do-not-merge/hold"

# member <plugins...> grants alice the members tier with the given plugins.
function member() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export MEMBERS_PLUGINS="${*}"
}

# reviewer <plugins...> grants alice the reviewers tier with the given
# plugins (the reviewers tier requires the members tier).
function reviewer() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export REVIEWERS=$'alice\ncarol'
    export REVIEWERS_PLUGINS="${*}"
}

begin_case "an empty message does nothing"
export ISSUE_KIND="issue"
run command.sh
assert_status 0
assert_out_has "PLUGINS:"
log_empty

begin_case "a message without commands does nothing"
export ISSUE_KIND="issue"
export MESSAGE="Nice work, thanks!"
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "an unknown command gets an unknown-command reply"
export ISSUE_KIND="issue"
export MESSAGE="/frobnicate"
run command.sh
assert_status 0
assert_out_has "[FAIL] Unknown command \`/frobnicate\`."
log_empty

begin_case "an existing command outside the granted tiers gets a permission reply"
export ISSUE_KIND="issue"
export MESSAGE="/hold"
run command.sh
assert_status 0
assert_out_has "[FAIL] You don't have permission to use the \`/hold\` command."
log_empty

begin_case "/hold by a member adds the hold label"
member hold
export MESSAGE="/hold"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "alice is a member"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "/hold cancel removes the hold label and re-checks auto-merge"
member hold
export MESSAGE="/hold cancel"
stub remove-labels.sh
stub check-auto-merge.sh
run command.sh
assert_status 0
log_has_line "stub remove-labels.sh ${HOLD_LABEL}"
log_has_line "stub check-auto-merge.sh"

begin_case "/hold is only available on pull requests"
member hold
export ISSUE_KIND="issue"
export MESSAGE="/hold"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "[FAIL] This command is only available on pull requests, not on issues."
log_lacks "stub add-labels.sh"

begin_case "/lgtm by a reviewer adds lgtm and re-checks auto-merge"
reviewer label-lgtm
export MESSAGE="/lgtm"
stub add-labels.sh
stub check-auto-merge.sh
run command.sh
assert_status 0
assert_out_has "alice is a reviewer"
log_has_line "stub add-labels.sh lgtm"
log_has_line "stub check-auto-merge.sh"

begin_case "/lgtm by the PR author is refused"
reviewer label-lgtm
export AUTHOR="alice"
export MESSAGE="/lgtm"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "[FAIL] You cannot LGTM your own PR."
log_lacks "stub add-labels.sh"

begin_case "/lgtm by a member who is not a reviewer is refused"
export AUTHOR_ASSOCIATION="MEMBER"
export REVIEWERS="carol"
export REVIEWERS_PLUGINS="label-lgtm"
export MESSAGE="/lgtm"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "[FAIL] You don't have permission to use the \`/lgtm\` command."
log_lacks "stub add-labels.sh"

begin_case "/remove-lgtm by a reviewer removes the lgtm label"
reviewer label-lgtm
export MESSAGE="/remove-lgtm"
stub remove-labels.sh
run command.sh
assert_status 0
log_has_line "stub remove-labels.sh lgtm"

begin_case "/assign without arguments assigns the commenter"
export ISSUE_KIND="issue"
export PLUGINS="assign"
export MESSAGE="/assign"
run command.sh
assert_status 0
log_has "curl -X POST"
log_has "/repos/wzshiming/example/issues/1/assignees"
log_has '{"assignees":["alice"]}'

begin_case "/assign @user assigns that user"
export ISSUE_KIND="issue"
export PLUGINS="assign"
export MESSAGE="/assign @carol"
run command.sh
assert_status 0
log_has '{"assignees":["carol"]}'
log_lacks '["alice"]'

begin_case "/assign a,b assigns each user separately"
export ISSUE_KIND="issue"
export PLUGINS="assign"
export MESSAGE="/assign dave,erin"
run command.sh
assert_status 0
log_has '{"assignees":["dave"]}'
log_has '{"assignees":["erin"]}'

begin_case "/unassign @user removes that assignee"
export ISSUE_KIND="issue"
export PLUGINS="assign"
export MESSAGE="/unassign @carol"
run command.sh
assert_status 0
log_has "curl -X DELETE"
log_has '{"assignees":["carol"]}'

begin_case "commands inside HTML comments are ignored"
member hold
export ISSUE_KIND="issue"
export MESSAGE=$'<!--\n/hold\n-->'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "a CRLF comment still dispatches the command"
member hold
export MESSAGE=$'/hold\r'
stub add-labels.sh
run command.sh
assert_status 0
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "several commands in one comment all run"
member hold
export PLUGINS="assign"
export MESSAGE=$'/hold\n/assign'
stub add-labels.sh
run command.sh
assert_status 0
log_has_line "stub add-labels.sh ${HOLD_LABEL}"
log_has '{"assignees":["alice"]}'
