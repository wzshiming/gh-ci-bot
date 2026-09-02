#!/usr/bin/env bash

# approve-workflow-runs.sh: approving all of the PR's workflow runs that
# are waiting for approval (status action_required). The approve endpoint
# only accepts runs of fork pull requests; for runs it rejects (e.g. held
# runs of same-repo PRs such as those pushed by the Copilot coding agent)
# the script falls back to re-running them, and only reports a run as
# failed when the rerun fails too.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# mkpull <sha> builds the reply to `gh api /repos/.../pulls/1`.
function mkpull() {
    export MOCK_PULL_JSON="${CASE_DIR}/pull.json"
    jq -n --arg sha "${1}" '{head: {sha: $sha}}' >"${MOCK_PULL_JSON}"
}

# mkruns [id...] builds the reply to `gh api /repos/.../actions/runs?...`.
function mkruns() {
    export MOCK_RUNS_JSON="${CASE_DIR}/runs.json"
    jq -n --args '{workflow_runs: [$ARGS.positional[] | {id: (. | tonumber)}]}' \
        "${@}" >"${MOCK_RUNS_JSON}"
}

# held [id...]: a PR whose given runs wait for approval, with the
# approve/rerun failure knobs cleared (reset_env does not know them).
function held() {
    unset MOCK_GH_APPROVE_FAIL MOCK_GH_RERUN_FAIL
    mkpull "abc123"
    mkruns "${@}"
}

begin_case "approves every waiting run"
held 111 222
run approve-workflow-runs.sh
assert_status 0
log_has "/repos/wzshiming/example/actions/runs?status=action_required&per_page=100&head_sha=abc123"
log_has_line "gh api --method POST -H Accept: application/vnd.github+json /repos/wzshiming/example/actions/runs/111/approve"
log_has_line "gh api --method POST -H Accept: application/vnd.github+json /repos/wzshiming/example/actions/runs/222/approve"
log_lacks "/rerun"
assert_out_has "All were approved"
assert_out_lacks "falling back to rerun"

begin_case "falls back to rerun when approve is rejected"
held 111
export MOCK_GH_APPROVE_FAIL=1
run approve-workflow-runs.sh
assert_status 0
assert_out_has "Approve rejected, falling back to rerun for workflow run ID: 111"
log_has_line "gh api --method POST -H Accept: application/vnd.github+json /repos/wzshiming/example/actions/runs/111/rerun"
assert_out_has "All were approved"
assert_out_lacks "Failed to approve"

begin_case "reports a run whose approve and rerun both fail"
held 111 222
export MOCK_GH_APPROVE_FAIL=1
export MOCK_GH_RERUN_FAIL=1
run approve-workflow-runs.sh
assert_status 0
log_has_line "gh api --method POST -H Accept: application/vnd.github+json /repos/wzshiming/example/actions/runs/111/rerun"
assert_out_has "Failed to approve:"
assert_out_has "  - https://github.com/wzshiming/example/actions/runs/111"
assert_out_has "  - https://github.com/wzshiming/example/actions/runs/222"
assert_out_lacks "All were approved"

begin_case "reports nothing to approve when no runs are waiting"
held
run approve-workflow-runs.sh
assert_status 0
assert_out_is "No workflow runs are waiting for approval"
log_lacks "/approve"
log_lacks "/rerun"

begin_case "does nothing for issues"
export ISSUE_KIND="issue"
run approve-workflow-runs.sh
assert_status 0
log_empty

begin_case "fails when the pull request cannot be fetched"
held 111
export MOCK_GH_FAIL=1
run approve-workflow-runs.sh
assert_status 1
assert_out_has "[FAIL] Failed to get the pull request."
log_lacks "/approve"
