#!/usr/bin/env bash

# approve-status.sh + owners.sh: approval integrity. An OWNERS load
# failure fails closed (a transient API error must never hand out the
# approved label), while a repository without OWNERS files keeps working.

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

begin_case "changed files but no OWNERS anywhere: 404s are not load failures"
stub_reconcile
mkfiles "src/main.go"
run_owned approve-status.sh approve alice
assert_status 1
assert_out_has "[FAIL] You are not an approver of any changed area."
log_lacks "stub add-labels.sh"
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

