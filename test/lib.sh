#!/usr/bin/env bash

# lib.sh - Harness sourced by every spec in test/specs.
#
# A spec is a plain bash script: it declares cases with begin_case, builds
# canned gh replies with the mk* fixture helpers, runs the real scripts
# under test with run, and checks the result with the assert_* and log_*
# helpers. gh, curl and git are replaced by the executables in test/mock,
# which log every invocation to ${MOCK_LOG} and serve the fixtures; nothing
# ever talks to GitHub.
#
# Every case gets a fresh temp dir, a fresh invocation log, a fresh stub
# dir and a reset baseline environment, so cases cannot leak state into
# each other. All PATH/env changes stay inside the spec process - no
# shell functions shadowing gh, no global state.

set -u

TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"
TEST_DIR="$(realpath -m "${TEST_DIR}")"
REPO_ROOT="$(realpath -m "${TEST_DIR}/..")"
MOCK_DIR="${TEST_DIR}/mock"
BIN_DIR="${REPO_ROOT}/bin"
PLUGINS_DIR="${REPO_ROOT}/plugins"
ENTRYPOINT="${REPO_ROOT}/entrypoint.sh"

SPEC_NAME="$(basename "${0}" .sh)"
BASE_PATH="${PATH}"
WORK_DIR="$(mktemp -d)"

CASE_NUM=0
CASE_DESC=""
CASE_FAILED=0
PASS=0
FAIL=0
OUTPUT=""
STATUS=0

# reset_env restores the baseline bot environment and clears every knob a
# case may have set, so no case inherits state from a previous one.
function reset_env() {
    export GH_REPOSITORY="wzshiming/example"
    export ISSUE_NUMBER="1"
    export ISSUE_KIND="pr"
    export LOGIN="alice"
    export AUTHOR="bob"
    export AUTHOR_ASSOCIATION="NONE"
    export TYPE="comment"
    export GH_TOKEN="mock-token"
    unset MESSAGE PLUGINS AUTHOR_PLUGINS CONTRIBUTORS_PLUGINS MEMBERS_PLUGINS REVIEWERS_PLUGINS \
        APPROVERS_PLUGINS MAINTAINERS_PLUGINS OWNERS_PLUGINS \
        REVIEWERS APPROVERS MAINTAINERS \
        RELEASE_NOTE_REQUIRED NEEDS_REBASE DCO_REQUIRED LABELS \
        BLOCK_MERGE_COMMITS BLOCK_INVALID_COMMIT_MESSAGES \
        ISSUE_REQUIRE_MATCHING_LABELS PR_REQUIRE_MATCHING_LABELS \
        BLUNDERBUSS_REVIEWER_COUNT DEFAULT_MERGE_METHOD DETAILS GREETING BOT_LOGIN \
        OWNERS_AREAS OWNERS_AREA_APPROVERS OWNERS_LABELS OWNERS_LOAD_FAILED branch \
        GITHUB_RUN_ID GITHUB_REPOSITORY GITHUB_SERVER_URL \
        MOCK_GH_FAIL MOCK_CURL_FAIL MOCK_GH_STDERR MOCK_REPO_FAIL \
        MOCK_PR_FILES_JSON MOCK_OWNERS_FILE MOCK_PR_FILES_FAIL MOCK_OWNERS_FAIL \
        MOCK_ISSUE_COMMENTS_JSON \
        MOCK_GIT_CLONE_FAIL MOCK_GIT_PARENTS MOCK_GIT_LOG MOCK_GIT_LOG_FAIL MOCK_GIT_PICK_FAIL MOCK_GIT_PUSH_FAIL
}

# begin_case <description> finishes the previous case and starts a new
# one with a fresh temp dir, log, stub dir and baseline environment.
function begin_case() {
    end_case
    CASE_NUM=$((CASE_NUM + 1))
    CASE_DESC="${1}"
    CASE_FAILED=0
    CASE_DIR="${WORK_DIR}/case-${CASE_NUM}"
    STUB_DIR="${CASE_DIR}/stubs"
    mkdir -p "${STUB_DIR}"
    export MOCK_LOG="${CASE_DIR}/mock.log"
    : >"${MOCK_LOG}"
    export MOCK_PR_JSON="${CASE_DIR}/pr.json"
    export MOCK_WIP_JSON="${CASE_DIR}/wip.json"
    export MOCK_SIZE_JSON="${CASE_DIR}/size.json"
    export MOCK_MERGEABLE_JSON="${CASE_DIR}/mergeable.json"
    export MOCK_MERGED_JSON="${CASE_DIR}/merged.json"
    export MOCK_TITLE_JSON="${CASE_DIR}/title.json"
    export MOCK_LABELS_JSON="${CASE_DIR}/labels.json"
    export MOCK_LABEL_LIST_JSON="${CASE_DIR}/label-list.json"
    export MOCK_PR_COMMITS_JSON="${CASE_DIR}/pr-commits.json"
    export PATH="${STUB_DIR}:${MOCK_DIR}:${BIN_DIR}:${BASE_PATH}"
    reset_env
    OUTPUT=""
    STATUS=0
}

function end_case() {
    if [[ -z "${CASE_DESC}" ]]; then
        return 0
    fi
    if [[ "${CASE_FAILED}" -eq 0 ]]; then
        PASS=$((PASS + 1))
        echo "ok ${CASE_NUM} - ${CASE_DESC}"
    else
        FAIL=$((FAIL + 1))
    fi
    CASE_DESC=""
}

# fail_case <message> marks the current case failed; the first failure of
# a case also dumps the captured output and the invocation log.
function fail_case() {
    if [[ "${CASE_FAILED}" -eq 0 ]]; then
        CASE_FAILED=1
        echo "not ok ${CASE_NUM} - ${CASE_DESC}"
        echo "#   ${1}"
        sed -e 's/^/#     output | /' <<<"${OUTPUT}"
        sed -e 's/^/#     log    | /' "${MOCK_LOG}"
    else
        echo "#   ${1}"
    fi
}

function finish() {
    local rc=$?
    if [[ "${rc}" -ne 0 ]]; then
        if [[ -n "${CASE_DESC}" ]]; then
            fail_case "spec aborted with exit code ${rc}"
        else
            echo "not ok - ${SPEC_NAME} aborted with exit code ${rc}"
            FAIL=$((FAIL + 1))
        fi
    fi
    end_case
    echo "# ${SPEC_NAME}: ${PASS} passed, ${FAIL} failed, $((PASS + FAIL)) total"
    rm -rf "${WORK_DIR}"
    if [[ "${FAIL}" -ne 0 ]]; then
        exit 1
    fi
}
trap finish EXIT

# run <command> [args...] runs a script under test, capturing combined
# stdout/stderr in ${OUTPUT} and the exit code in ${STATUS}. Bare names
# (e.g. check-wip.sh) resolve through the per-case PATH: stubs first,
# then the mocks, then the real bin scripts.
function run() {
    local out="${CASE_DIR}/output"
    STATUS=0
    "${@}" >"${out}" 2>&1 || STATUS=$?
    OUTPUT="$(cat "${out}")"
}

# stub <script-name> [exit-code] replaces a helper script (e.g.
# add-labels.sh, remove-labels.sh, check-auto-merge.sh) with a logging
# no-op for unit-level isolation. Invocations show up in the log as
# "stub <script-name> <args>".
function stub() {
    local name="${1}"
    local rc="${2:-0}"
    cat >"${STUB_DIR}/${name}" <<EOF
#!/usr/bin/env bash
echo "stub ${name}\${*:+ \${*}}" >>"\${MOCK_LOG}"
exit ${rc}
EOF
    chmod +x "${STUB_DIR}/${name}"
}

# mkpr <body> [label...] builds the reply to
# `gh pr view --json body,labels`.
function mkpr() {
    local body="${1}"
    shift
    jq -n --arg body "${body}" --args \
        '{body: $body, labels: [$ARGS.positional[] | {name: .}]}' \
        "${@}" >"${MOCK_PR_JSON}"
}

# mkwip <isDraft> <title> [label...] builds the reply to
# `gh pr view --json isDraft,title,labels`, also served for the
# `--json isDraft` draft check of blunderbuss.sh.
function mkwip() {
    local draft="${1}"
    local title="${2}"
    shift 2
    jq -n --argjson draft "${draft}" --arg title "${title}" --args \
        '{isDraft: $draft, title: $title, labels: [$ARGS.positional[] | {name: .}]}' \
        "${@}" >"${MOCK_WIP_JSON}"
}

# mksize <additions> <deletions> [label...] builds the reply to
# `gh pr view --json additions,deletions,labels`.
function mksize() {
    local additions="${1}"
    local deletions="${2}"
    shift 2
    jq -n --argjson additions "${additions}" --argjson deletions "${deletions}" --args \
        '{additions: $additions, deletions: $deletions, labels: [$ARGS.positional[] | {name: .}]}' \
        "${@}" >"${MOCK_SIZE_JSON}"
}

# mklabels [label...] builds the reply to `gh <kind> view --json labels`.
function mklabels() {
    jq -n --args '{labels: [$ARGS.positional[] | {name: .}]}' "${@}" >"${MOCK_LABELS_JSON}"
}

# mkmergeable <state> <mergeable> [label...] builds the reply to
# `gh pr view --json mergeable,state,labels`.
function mkmergeable() {
    local state="${1}"
    local mergeable="${2}"
    shift 2
    jq -n --arg state "${state}" --arg mergeable "${mergeable}" --args \
        '{mergeable: $mergeable, state: $state, labels: [$ARGS.positional[] | {name: .}]}' \
        "${@}" >"${MOCK_MERGEABLE_JSON}"
}

# mkmerged <state> <oid> <title> builds the reply to
# `gh pr view --json state,mergeCommit,title`.
function mkmerged() {
    jq -n --arg state "${1}" --arg oid "${2}" --arg title "${3}" \
        '{state: $state, mergeCommit: {oid: $oid}, title: $title}' >"${MOCK_MERGED_JSON}"
}

# mktitle <title> [label...] builds the reply to
# `gh pr view --json title,labels`.
function mktitle() {
    local title="${1}"
    shift
    jq -n --arg title "${title}" --args \
        '{title: $title, labels: [$ARGS.positional[] | {name: .}]}' \
        "${@}" >"${MOCK_TITLE_JSON}"
}

# mkcommits [<parents>:<message>...] builds the reply to the PR commits
# query `gh api /repos/<repo>/pulls/<n>/commits`, one commit per argument
# with the given number of parents (more than 1 makes it a merge commit)
# and commit message.
function mkcommits() {
    jq -n --args \
        '[$ARGS.positional[] | capture("^(?<parents>[0-9]+):(?<message>.*)"; "m")] |
            to_entries |
            map({
                sha: ("sha-" + ((.key + 1) | tostring)),
                parents: [range(.value.parents | tonumber) | {sha: ("parent-" + tostring)}],
                commit: {message: .value.message}
            })' \
        "${@}" >"${MOCK_PR_COMMITS_JSON}"
}

# mkrepolabels [label...] builds the reply to
# `gh label list --json name`: the labels existing in the repository.
function mkrepolabels() {
    jq -n --args '[$ARGS.positional[] | {name: .}]' "${@}" >"${MOCK_LABEL_LIST_JSON}"
}

# mkfiles [path...] builds the reply to the changed-files query
# `gh api /repos/<repo>/pulls/<n>/files`, one changed file per argument.
function mkfiles() {
    export MOCK_PR_FILES_JSON="${CASE_DIR}/pr-files.json"
    jq -n --args '[$ARGS.positional[] | {filename: .}]' "${@}" >"${MOCK_PR_FILES_JSON}"
}

# mkowners <yaml> builds the OWNERS file content served for every
# directory of the repository by the mocked
# `gh api /repos/<repo>/contents/<dir>/OWNERS`.
function mkowners() {
    export MOCK_OWNERS_FILE="${CASE_DIR}/owners"
    printf '%s\n' "${1}" >"${MOCK_OWNERS_FILE}"
}

# mkissuecomments <login> <body> [<login> <body>...] builds the reply to
# the issue comments query `gh api /repos/<repo>/issues/<n>/comments`,
# numbering the comment ids 1, 2, ... in order.
function mkissuecomments() {
    export MOCK_ISSUE_COMMENTS_JSON="${CASE_DIR}/issue-comments.json"
    local json="[]" id=0 login body
    while [[ "${#}" -ge 2 ]]; do
        login="${1}"
        body="${2}"
        shift 2
        id=$((id + 1))
        json="$(jq --arg login "${login}" --arg body "${body}" --argjson id "${id}" \
            '. + [{id: $id, user: {login: $login}, body: $body}]' <<<"${json}")"
    done
    printf '%s\n' "${json}" >"${MOCK_ISSUE_COMMENTS_JSON}"
}

# assert_status <expected> checks the exit code of the last run.
function assert_status() {
    if [[ "${STATUS}" -ne "${1}" ]]; then
        fail_case "expected exit status ${1}, got ${STATUS}"
    fi
}

# assert_out_is <text> checks the exact combined output of the last run.
function assert_out_is() {
    if [[ "${OUTPUT}" != "${1}" ]]; then
        fail_case "expected output \"${1}\", got \"${OUTPUT}\""
    fi
}

# assert_out_has <text> checks that the output contains the given text.
function assert_out_has() {
    if ! grep -qF -e "${1}" <<<"${OUTPUT}"; then
        fail_case "expected output to contain \"${1}\""
    fi
}

# assert_out_lacks <text> checks that the output lacks the given text.
function assert_out_lacks() {
    if grep -qF -e "${1}" <<<"${OUTPUT}"; then
        fail_case "expected output not to contain \"${1}\""
    fi
}

# log_has <text> checks that some gh/curl/stub invocation contains the
# given text.
function log_has() {
    if ! grep -qF -e "${1}" "${MOCK_LOG}"; then
        fail_case "expected an invocation containing \"${1}\""
    fi
}

# log_has_line <text> checks that some invocation is exactly the given
# line, e.g. "stub add-labels.sh release-note" - unlike log_has this does
# not also match "stub add-labels.sh release-note-none".
function log_has_line() {
    if ! grep -qxF -e "${1}" "${MOCK_LOG}"; then
        fail_case "expected an invocation \"${1}\""
    fi
}

# log_before <first> <second> checks that the first invocation containing
# <first> appears before the first invocation containing <second>, proving
# one action happened before another. Either text missing entirely is also
# a failure.
function log_before() {
    local first second
    first="$(grep -nF -e "${1}" "${MOCK_LOG}" | head -1 | cut -d: -f1)"
    second="$(grep -nF -e "${2}" "${MOCK_LOG}" | head -1 | cut -d: -f1)"
    if [[ -z "${first}" ]]; then
        fail_case "expected an invocation containing \"${1}\""
    elif [[ -z "${second}" ]]; then
        fail_case "expected an invocation containing \"${2}\""
    elif [[ "${first}" -ge "${second}" ]]; then
        fail_case "expected an invocation containing \"${1}\" before one containing \"${2}\""
    fi
}

# log_lacks <text> checks that no gh/curl/stub invocation contains the
# given text, proving a mutation did not happen.
function log_lacks() {
    if grep -qF -e "${1}" "${MOCK_LOG}"; then
        fail_case "expected no invocation containing \"${1}\""
    fi
}

# log_empty checks that no gh/curl/stub invocation happened at all.
function log_empty() {
    if [[ -s "${MOCK_LOG}" ]]; then
        fail_case "expected no invocations at all"
    fi
}
