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

# contributor <plugins...> grants alice the contributors tier with the given
# plugins.
function contributor() {
    export AUTHOR_ASSOCIATION="CONTRIBUTOR"
    export CONTRIBUTORS_PLUGINS="${*}"
}

# reviewer <plugins...> grants alice the reviewers tier with the given
# plugins (the reviewers tier requires the members tier).
function reviewer() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export REVIEWERS=$'alice\ncarol'
    export REVIEWERS_PLUGINS="${*}"
}

# No-command comments are the common case and ISSUE_KIND stays "pr" here:
# command.sh must do nothing at all, in particular not fetch the changed
# files and the OWNERS chain of the PR.
begin_case "an empty message does nothing"
run command.sh
assert_status 0
assert_out_is ""
log_empty

begin_case "a message without commands does nothing"
export MESSAGE="Nice work, thanks!"
run command.sh
assert_status 0
assert_out_is ""
log_empty

# The counterpart: a comment that does carry a command still loads the
# OWNERS chain of the PR, starting with its changed files.
begin_case "a command on a PR fetches the changed files for the OWNERS chain"
member hold
export MESSAGE="/hold"
stub add-labels.sh
run command.sh
assert_status 0
log_has "/pulls/1/files"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

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

# The member tier is granted to these associations only.
for association in OWNER MEMBER COLLABORATOR; do
    begin_case "the ${association} association gets the member tier"
    member hold
    export AUTHOR_ASSOCIATION="${association}"
    export MESSAGE="/hold"
    stub add-labels.sh
    run command.sh
    assert_status 0
    assert_out_has "alice is a member"
    log_has_line "stub add-labels.sh ${HOLD_LABEL}"
done

# Previous contributors are not members, and neither are the other values
# GitHub uses (FIRST_TIME_CONTRIBUTOR, FIRST_TIMER, MANNEQUIN).
for association in CONTRIBUTOR FIRST_TIME_CONTRIBUTOR FIRST_TIMER MANNEQUIN; do
    begin_case "the ${association} association does not get the member tier"
    member hold
    export AUTHOR_ASSOCIATION="${association}"
    export MESSAGE="/hold"
    stub add-labels.sh
    run command.sh
    assert_status 0
    assert_out_lacks "alice is a member"
    assert_out_has "[FAIL] You don't have permission to use the \`/hold\` command."
    log_lacks "stub add-labels.sh"
done

# The contributors tier covers previous contributors and every member: GitHub
# reports a single association, so members never show up as CONTRIBUTOR.
for association in CONTRIBUTOR COLLABORATOR MEMBER OWNER; do
    begin_case "the ${association} association gets the contributors tier"
    contributor hold
    export AUTHOR_ASSOCIATION="${association}"
    export MESSAGE="/hold"
    stub add-labels.sh
    run command.sh
    assert_status 0
    assert_out_has "alice is a contributor"
    log_has_line "stub add-labels.sh ${HOLD_LABEL}"
done

for association in FIRST_TIME_CONTRIBUTOR FIRST_TIMER MANNEQUIN NONE; do
    begin_case "the ${association} association does not get the contributors tier"
    contributor hold
    export AUTHOR_ASSOCIATION="${association}"
    export MESSAGE="/hold"
    stub add-labels.sh
    run command.sh
    assert_status 0
    assert_out_lacks "alice is a contributor"
    assert_out_has "[FAIL] You don't have permission to use the \`/hold\` command."
    log_lacks "stub add-labels.sh"
done

begin_case "a CONTRIBUTOR listed in REVIEWERS does not get the reviewer tier"
reviewer label-lgtm
export AUTHOR_ASSOCIATION="CONTRIBUTOR"
export MESSAGE="/lgtm"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "alice is a reviewer"
assert_out_has "[FAIL] You don't have permission to use the \`/lgtm\` command."
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

begin_case "a command after an unterminated comment is ignored"
member hold
export MESSAGE=$'<!--\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "commands inside fenced code blocks are ignored"
member hold
export MESSAGE=$'```\n/hold\n```'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "a command after a closed fence still runs"
member hold
export MESSAGE=$'```\n/merge\n```\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "Exec command: hold"
assert_out_lacks "Exec command: merge"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "an unterminated fence suppresses commands to the end"
member hold
export MESSAGE=$'```bash\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "a longer fence is not closed by a shorter one"
member hold
export MESSAGE=$'````\n```\n/merge\n````\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "Exec command: hold"
assert_out_lacks "Exec command: merge"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "a fence line with an info string does not close the fence"
member hold
export MESSAGE=$'```\n```bash\n/merge\n```\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "Exec command: hold"
assert_out_lacks "Exec command: merge"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "tilde fences suppress commands"
member hold
export MESSAGE=$'~~~\n/hold\n~~~'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "a tilde line does not close a backtick fence"
member hold
export MESSAGE=$'```\n~~~\n/merge\n```\n/hold'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "Exec command: hold"
assert_out_lacks "Exec command: merge"
log_has_line "stub add-labels.sh ${HOLD_LABEL}"

begin_case "an invalid backtick opener stays literal text"
member hold
export MESSAGE=$'```lang```\ntext\n```\n/hold\n```'
stub add-labels.sh
run command.sh
assert_status 0
assert_out_lacks "Exec command"
log_empty

begin_case "arguments are never glob-expanded"
member label
export MESSAGE="/label *"
stub add-labels.sh
mkdir -p "${CASE_DIR}/glob-cwd"
touch "${CASE_DIR}/glob-cwd/glob-canary.txt"
pushd "${CASE_DIR}/glob-cwd" >/dev/null
run command.sh
popd >/dev/null
assert_status 0
log_has_line "stub add-labels.sh *"
log_lacks "glob-canary.txt"

begin_case "an ungranted command whose dir has a different name gets a permission reply"
export ISSUE_KIND="issue"
export MESSAGE="/remove-approve"
run command.sh
assert_status 0
assert_out_has "[FAIL] You don't have permission to use the \`/remove-approve\` command."
log_empty

begin_case "a substring of a plugin name is still an unknown command"
export ISSUE_KIND="issue"
export MESSAGE="/erg"
run command.sh
assert_status 0
assert_out_has "[FAIL] Unknown command \`/erg\`."
log_empty

begin_case "glob characters in a command name are not expanded"
export ISSUE_KIND="issue"
export MESSAGE='/h*'
run command.sh
assert_status 0
assert_out_has "[FAIL] Unknown command \`/h*\`."
log_empty

begin_case "reviewer matching is login-case-insensitive"
export AUTHOR_ASSOCIATION="MEMBER"
export REVIEWERS=$'Alice\ncarol'
export REVIEWERS_PLUGINS="label-lgtm"
export MESSAGE="/lgtm"
stub add-labels.sh
stub check-auto-merge.sh
run command.sh
assert_status 0
assert_out_has "alice is a reviewer"
log_has_line "stub add-labels.sh lgtm"
