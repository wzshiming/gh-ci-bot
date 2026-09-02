#!/usr/bin/env bash

# approve-status.sh + owners.sh: approval integrity. An OWNERS load
# failure fails closed (a transient API error must never hand out the
# approved label), stale approvers are dropped on sync, OWNERS files are
# read from the PR's base branch, and login comparisons are
# case-insensitive while the stored casing is preserved.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# run_owned <cmd...> mirrors the real call chain of command.sh and
# entrypoint.sh: source owners.sh, load the OWNERS data, then run the
# command in the resulting environment.
function run_owned() {
    run bash -c 'source "$1/owners.sh"; load_owners_for_pr; shift; "$@"' bash "${BIN_DIR}" "$@"
}

# stub_reconcile stubs every mutation helper reconcile_label may call.
function stub_reconcile() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

# mkfiles <file...> builds the changed-files reply to pulls/N/files.
function mkfiles() {
    export MOCK_PR_FILES_JSON="${CASE_DIR}/files.json"
    jq -n --args '[$ARGS.positional[] | {filename: .}]' "${@}" >"${MOCK_PR_FILES_JSON}"
}

# mkowners <dir> <line...> writes the OWNERS fixture of a directory
# ("." = repository root); directories without a fixture serve a 404.
function mkowners() {
    export MOCK_OWNERS_DIR="${CASE_DIR}/owners"
    mkdir -p "${MOCK_OWNERS_DIR}"
    local dir="${1}"
    shift
    local name="OWNERS"
    if [[ "${dir}" != "." ]]; then
        name="${dir//\//__}__OWNERS"
    fi
    printf '%s\n' "${@}" >"${MOCK_OWNERS_DIR}/${name}"
}

# mkbase <branch> builds the reply to `gh pr view --json baseRefName`.
function mkbase() {
    export MOCK_PR_BASE_JSON="${CASE_DIR}/base.json"
    jq -n --arg b "${1}" '{baseRefName: $b}' >"${MOCK_PR_BASE_JSON}"
}

# mkstatus <state-line...> seeds the bot's status comment (id 12345) with
# the given machine-readable state lines.
function mkstatus() {
    local body="<!-- ci-bot-approve-status"
    local line
    for line in "${@}"; do
        body="${body}
${line}"
    done
    body="${body}
-->
[APPROVALNOTIFIER] seeded"
    export MOCK_COMMENTS_JSON="${CASE_DIR}/comments.json"
    jq -n --arg body "${body}" \
        '[{id: 12345, user: {login: "mock-bot"}, body: $body}]' >"${MOCK_COMMENTS_JSON}"
}

# --- OWNERS load failures fail closed ---------------------------------

begin_case "approve fails closed when the whole API is down"
stub_reconcile
export MOCK_GH_FAIL=1
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Failed to load OWNERS data, not changing approval state."
log_lacks "stub add-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "approve fails closed when the changed-files query fails"
stub_reconcile
export branch="main"
export MOCK_GH_FAIL=1
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Failed to load OWNERS data, not changing approval state."
log_lacks "stub add-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "approve fails closed when an OWNERS fetch fails with a non-404 error"
stub_reconcile
mkfiles "src/main.go"
export MOCK_OWNERS_FAIL=1
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Failed to load OWNERS data, not changing approval state."
log_lacks "stub add-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "the approve plugin fails closed on a load failure"
stub_reconcile
export MOCK_GH_FAIL=1
run_owned "${PLUGINS_DIR}/label-approve/approve.plugin.sh"
assert_status 1
assert_out_has "[FAIL] Failed to load OWNERS data, not changing approval state."
log_lacks "stub add-labels.sh"

begin_case "unapprove fails closed when the OWNERS load fails"
stub_reconcile
export MOCK_GH_FAIL=1
run_owned approve-status.sh unapprove alice
assert_status 1
assert_out_has "[FAIL] Failed to load OWNERS data, not changing approval state."
log_lacks "stub remove-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "sync skips without mutating when the OWNERS load fails"
stub_reconcile
export MOCK_GH_FAIL=1
run_owned approve-status.sh sync
assert_status 0
assert_out_has "skipping"
log_lacks "stub"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "check fails closed when the OWNERS load fails"
export MOCK_GH_FAIL=1
run_owned approve-status.sh check
assert_status 1

begin_case "a load failure does not break command dispatch"
stub add-labels.sh
export AUTHOR_ASSOCIATION="MEMBER"
export MEMBERS_PLUGINS="hold"
export MESSAGE="/hold"
export MOCK_GH_FAIL=1
run command.sh
assert_status 0
log_has_line "stub add-labels.sh do-not-merge/hold"

begin_case "approve fails closed when the comment listing fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
export MOCK_COMMENTS_FAIL=1
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Failed to read the approval status, not changing approval state."
log_lacks "stub add-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "unapprove fails closed when the comment listing fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
export MOCK_COMMENTS_FAIL=1
run_owned approve-status.sh unapprove alice
assert_status 1
assert_out_has "[FAIL] Failed to read the approval status, not changing approval state."
log_lacks "stub remove-labels.sh"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "approve leaves the label alone when saving the status fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
export MOCK_MUTATE_FAIL=1
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] Failed to save the approval status, not changing approval state."
log_lacks "stub add-labels.sh"
log_lacks "stub check-auto-merge.sh"

begin_case "unapprove leaves the label alone when saving the status fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
mkstatus "src alice"
export MOCK_MUTATE_FAIL=1
run_owned approve-status.sh unapprove alice
assert_status 1
assert_out_has "[FAIL] Failed to save the approval status, not changing approval state."
log_lacks "stub remove-labels.sh"
log_lacks "stub add-labels.sh"

begin_case "sync makes no label change when the comment read fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
export MOCK_COMMENTS_FAIL=1
run_owned approve-status.sh sync
assert_status 1
log_lacks "stub"
log_lacks "-X POST"
log_lacks "-X PATCH"

begin_case "sync makes no label change when saving the status fails"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
export MOCK_MUTATE_FAIL=1
run_owned approve-status.sh sync
assert_status 1
log_lacks "stub"

begin_case "check fails closed when the comment read fails"
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - bob"
export MOCK_COMMENTS_FAIL=1
run_owned approve-status.sh check
assert_status 1

begin_case "a base-branch lookup that fails after printing marks the load failed"
cat >"${STUB_DIR}/gh" <<'EOF'
#!/usr/bin/env bash
echo '{"baseRefName":"release-1.0"}'
exit 1
EOF
chmod +x "${STUB_DIR}/gh"
run bash -c 'source "$1/owners.sh"; echo "failed=${OWNERS_LOAD_FAILED}"' bash "${BIN_DIR}"
assert_status 0
assert_out_has "failed=1"

begin_case "a late OWNERS failure leaves no partial approver data"
mkfiles "a/f" "c/d/g"
mkowners "a" "approvers:" "  - alice"
mkowners "c/d" "approvers:" "  - carol"
export MOCK_OWNERS_FAIL_PATH="c/OWNERS"
run bash -c 'source "$1/owners.sh"; load_owners_for_pr; printf "failed=%s areas=<%s> area_approvers=<%s>\n" "${OWNERS_LOAD_FAILED}" "${OWNERS_AREAS}" "${OWNERS_AREA_APPROVERS}"' bash "${BIN_DIR}"
assert_status 0
assert_out_has "failed=1"
assert_out_has "areas=<>"
assert_out_has "area_approvers=<>"

# --- a repo legitimately without OWNERS files keeps working -----------

begin_case "changed files but no OWNERS anywhere: approve stays stateless"
stub_reconcile
mkfiles "src/main.go"
run_owned approve-status.sh approve alice
assert_status 0
log_has_line "stub add-labels.sh approved"
log_has_line "stub check-auto-merge.sh"
log_lacks "-X POST"

begin_case "no changed files and no OWNERS: approve stays stateless"
stub_reconcile
run_owned approve-status.sh approve alice
assert_status 0
log_has_line "stub add-labels.sh approved"
log_has_line "stub check-auto-merge.sh"
log_lacks "-X POST"

begin_case "404 OWNERS are not failures: env APPROVERS still approve"
stub_reconcile
export APPROVERS="alice"
mkfiles "src/main.go"
run_owned approve-status.sh approve alice
assert_status 0
assert_out_has "All areas approved."
log_has_line "stub add-labels.sh approved"
log_has "-X POST"

# --- stale approvers ---------------------------------------------------

begin_case "sync drops approvals from users removed from OWNERS"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
mkstatus "src bob"
run_owned approve-status.sh sync
assert_status 0
log_has "-X PATCH /repos/wzshiming/example/issues/comments/12345"
log_has "NOT APPROVED"
log_lacks "src bob"
log_has_line "stub remove-labels.sh approved"
log_lacks "stub add-labels.sh"

begin_case "sync keeps approvals whose OWNERS casing differs"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
mkstatus "src Alice"
run_owned approve-status.sh sync
assert_status 0
log_has "src Alice"
log_has_line "stub add-labels.sh approved"
log_lacks "stub remove-labels.sh"

# --- OWNERS ref --------------------------------------------------------

begin_case "OWNERS are read from the PR base branch"
mkbase "release-1.0"
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
run bash -c 'source "$1/owners.sh"; load_owners_for_pr' bash "${BIN_DIR}"
assert_status 0
log_has "--json baseRefName"
log_has "ref=release-1.0"
log_lacks "ref=main"

begin_case "non-PR contexts fall back to the default branch"
export ISSUE_KIND="issue"
run bash -c 'source "$1/owners.sh"; echo "branch=${branch}"' bash "${BIN_DIR}"
assert_status 0
assert_out_has "branch=main"
log_lacks "--json baseRefName"

# --- case-insensitive logins -------------------------------------------

begin_case "approve matches OWNERS approvers case-insensitively"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - Alice"
run_owned approve-status.sh approve alice
assert_status 0
assert_out_has "Area 'src' approved by alice"
log_has "src alice"
log_has_line "stub add-labels.sh approved"

begin_case "unapprove removes an approval recorded with other casing"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - alice"
mkstatus "src alice"
run_owned approve-status.sh unapprove ALICE
assert_status 0
log_has "NOT APPROVED"
log_has_line "stub remove-labels.sh approved"

begin_case "author self-approval matches the OWNERS casing"
stub_reconcile
mkfiles "src/main.go"
mkowners "src" "approvers:" "  - Bob"
run_owned approve-status.sh sync
assert_status 0
assert_out_has "PR author bob is an approver"
log_has "src bob"
log_has_line "stub add-labels.sh approved"
