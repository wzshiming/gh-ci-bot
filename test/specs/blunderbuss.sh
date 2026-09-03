#!/usr/bin/env bash

# blunderbuss.sh: reviewers are requested from the OWNERS files nearest to
# the changed files, treating every path as a whole even when it contains
# whitespace or glob characters.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "a path with spaces is one file mapping to one area"
stub add-reviewer.sh
mkwip false "title"
mkfiles "docs/my file.md"
mkowners "reviewers: [dave]"
run blunderbuss.sh
assert_status 0
assert_out_has "- docs/my file.md"
assert_out_lacks "- file.md"
assert_out_has "Add dave for docs"
assert_out_lacks "Add dave for ."
log_has "contents/docs/OWNERS"
log_lacks "example/contents/OWNERS"
log_has_line "stub add-reviewer.sh dave"

begin_case "a directory with spaces gets its reviewer requested"
stub add-reviewer.sh
mkwip false "title"
mkfiles "my docs/guide.md"
mkowners "reviewers: [dave]"
run blunderbuss.sh
assert_status 0
assert_out_has "Add dave for my docs"
log_has "contents/my docs/OWNERS"
log_has_line "stub add-reviewer.sh dave"

begin_case "glob characters in a path are not expanded"
stub add-reviewer.sh
mkwip false "title"
mkfiles "*.md"
mkowners "reviewers: [dave]"
touch "${CASE_DIR}/decoy.md"
run bash -c 'cd "${1}" && blunderbuss.sh' bash "${CASE_DIR}"
assert_status 0
assert_out_has "- *.md"
assert_out_lacks "- decoy.md"
log_has_line "stub add-reviewer.sh dave"

begin_case "a PR with no changed files requests no reviewers"
stub add-reviewer.sh
mkwip false "title"
mkowners "reviewers: [dave]"
run blunderbuss.sh
assert_status 0
assert_out_has "No reviewers found to request, skipping"
log_lacks "stub add-reviewer.sh"
