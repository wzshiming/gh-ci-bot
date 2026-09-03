#!/usr/bin/env bash

# owners.sh: load_owners_for_pr maps every changed file to its area (the
# nearest ancestor directory whose OWNERS file lists approvers) without
# splitting paths on whitespace or expanding glob characters, and flags a
# failed fetch of an OWNERS file or of the changed files as incomplete data.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# load_owners <working-dir> sources the real owners.sh, loads the OWNERS
# data of the PR and prints the exported results between markers.
function load_owners() {
    run bash -c 'cd "${1}" && source owners.sh &&
        load_owners_for_pr &&
        echo "areas=<${OWNERS_AREAS}>" &&
        echo "area_approvers=<${OWNERS_AREA_APPROVERS}>" &&
        echo "load_failed=<${OWNERS_LOAD_FAILED:-}>"' bash "${1:-.}"
}

begin_case "a path with spaces is one file mapping to one area"
mkfiles "docs/my file.md"
mkowners "approvers: [carol]"
load_owners
assert_status 0
assert_out_has "areas=<docs>"
assert_out_has "area_approvers=<docs carol>"
assert_out_lacks "- .: carol"

begin_case "approvers of parent directories still apply to nested areas"
export APPROVERS="root-admin"
mkfiles "docs/my file.md"
mkowners "approvers: [carol]"
load_owners
assert_status 0
assert_out_has "areas=<docs>"
assert_out_has "area_approvers=<docs carol root-admin>"

begin_case "glob characters in a path are not expanded"
mkfiles "[d]ocs/guide.md"
mkowners "approvers: [carol]"
mkdir -p "${CASE_DIR}/docs"
touch "${CASE_DIR}/docs/guide.md"
load_owners "${CASE_DIR}"
assert_status 0
assert_out_has "areas=<[d]ocs>"
assert_out_lacks "areas=<docs>"

begin_case "a PR with no changed files yields no areas"
mkowners "approvers: [carol]"
load_owners
assert_status 0
assert_out_has "areas=<>"
assert_out_has "area_approvers=<>"

begin_case "a missing OWNERS file is not a load failure"
export APPROVERS="root-admin"
mkfiles "README.md"
load_owners
assert_status 0
assert_out_has "area_approvers=<. root-admin>"
assert_out_has "load_failed=<>"
assert_out_lacks "OWNERS: failed"

begin_case "a failed OWNERS fetch flags the load as failed"
export APPROVERS="root-admin"
mkfiles "docs/guide.md"
export MOCK_OWNERS_FAIL=1
load_owners
assert_status 0
assert_out_has "OWNERS: failed to fetch docs/OWNERS"
assert_out_has "load_failed=<1>"

begin_case "a failed changed-files fetch flags the load as failed"
mkowners "approvers: [carol]"
export MOCK_PR_FILES_FAIL=1
load_owners
assert_status 0
assert_out_has "OWNERS: failed to fetch the changed files"
assert_out_has "areas=<>"
assert_out_has "load_failed=<1>"

begin_case "a failed default-branch lookup flags the load as failed"
mkfiles "README.md"
mkowners "approvers: [carol]"
export MOCK_REPO_FAIL=1
load_owners
assert_status 0
assert_out_has "OWNERS: failed to resolve the default branch"
assert_out_has "load_failed=<1>"

begin_case "stderr chatter on a successful fetch is not OWNERS content"
mkfiles "README.md"
mkowners "approvers: [carol]"
export MOCK_GH_STDERR="* Request at 2026-09-03 12:00:00"
load_owners
assert_status 0
assert_out_has "area_approvers=<. carol>"
assert_out_has "load_failed=<>"

begin_case "a fresh load clears an inherited failure flag"
mkfiles "README.md"
mkowners "approvers: [carol]"
export OWNERS_LOAD_FAILED=1
load_owners
assert_status 0
assert_out_has "area_approvers=<. carol>"
assert_out_has "load_failed=<>"
