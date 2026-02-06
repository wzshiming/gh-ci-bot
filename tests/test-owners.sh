#!/usr/bin/env bash

# Tests for owners.sh utility functions

SCRIPT_DIR="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m "${SCRIPT_DIR}/..")"

PASS=0
FAIL=0

function assert_eq() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "PASS: ${description}"
        PASS=$((PASS + 1))
    else
        echo "FAIL: ${description}"
        echo "  expected: '${expected}'"
        echo "  actual:   '${actual}'"
        FAIL=$((FAIL + 1))
    fi
}

# Source owners.sh functions without running the main logic
# We do this by setting ISSUE_KIND to something other than "pr"
ISSUE_KIND="issue"
source "${ROOT}/bin/owners.sh"

# Test owners_get_parent
assert_eq "get_parent of file in subdir" "pkg/api" "$(owners_get_parent "pkg/api/handler.go")"
assert_eq "get_parent of file in root" "" "$(owners_get_parent "main.go")"
assert_eq "get_parent of nested path" "a/b" "$(owners_get_parent "a/b/c")"
assert_eq "get_parent of single dir" "" "$(owners_get_parent "pkg")"

# Test owners_common_prefix
assert_eq "common prefix: same dir" "pkg/api" "$(owners_common_prefix "pkg/api/handler.go" "pkg/api/server.go")"
assert_eq "common prefix: sibling dirs" "pkg" "$(owners_common_prefix "pkg/api/handler.go" "pkg/util/helper.go")"
assert_eq "common prefix: root level" "" "$(owners_common_prefix "main.go" "pkg/api/handler.go")"
assert_eq "common prefix: single file" "pkg/api" "$(owners_common_prefix "pkg/api/handler.go")"
assert_eq "common prefix: deeply nested" "a/b" "$(owners_common_prefix "a/b/c/d.go" "a/b/e/f.go")"
assert_eq "common prefix: three files different dirs" "pkg" "$(owners_common_prefix "pkg/api/handler.go" "pkg/util/helper.go" "pkg/model/user.go")"
assert_eq "common prefix: all root files" "" "$(owners_common_prefix "main.go" "go.mod" "go.sum")"

# Test OWNERS YAML parsing with yq
tmpdir=$(mktemp -d)
cat > "${tmpdir}/OWNERS" <<EOF
reviewers:
  - alice
  - bob
approvers:
  - charlie
  - dave
EOF

reviewers="$(cat "${tmpdir}/OWNERS" | yq e '.reviewers | .[]' 2>/dev/null)"
assert_eq "yq parses reviewers" "alice
bob" "${reviewers}"

approvers="$(cat "${tmpdir}/OWNERS" | yq e '.approvers | .[]' 2>/dev/null)"
assert_eq "yq parses approvers" "charlie
dave" "${approvers}"

# Test OWNERS file with only reviewers
cat > "${tmpdir}/OWNERS" <<EOF
reviewers:
  - alice
EOF

reviewers="$(cat "${tmpdir}/OWNERS" | yq e '.reviewers | .[]' 2>/dev/null)"
assert_eq "yq parses reviewers only" "alice" "${reviewers}"

approvers="$(cat "${tmpdir}/OWNERS" | yq e '.approvers | .[]' 2>/dev/null)"
assert_eq "yq handles missing approvers" "" "${approvers}"

rm -rf "${tmpdir}"

# Summary
echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ ${FAIL} -gt 0 ]]; then
    exit 1
fi
