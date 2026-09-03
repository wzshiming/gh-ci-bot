#!/usr/bin/env bash

# owners.sh: load_owners_for_pr maps every changed file to its area (the
# nearest ancestor directory whose OWNERS file lists approvers) without
# splitting paths on whitespace or expanding glob characters.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# load_owners <working-dir> sources the real owners.sh, loads the OWNERS
# data of the PR and prints the exported results between markers.
function load_owners() {
    run bash -c 'cd "${1}" && source owners.sh &&
        load_owners_for_pr &&
        echo "areas=<${OWNERS_AREAS}>" &&
        echo "area_approvers=<${OWNERS_AREA_APPROVERS}>"' bash "${1:-.}"
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
