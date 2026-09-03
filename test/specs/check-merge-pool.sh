#!/usr/bin/env bash

# check-merge-pool.sh: the scheduled sync lists every open PR carrying
# both the "lgtm" and "approved" labels and evaluates the candidates
# oldest first, one at a time, through check-auto-merge.sh, so merges are
# serialized. A failing candidate does not stop the reconcile, and a
# failing pool query fails the sync instead of silently doing nothing.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# stub_pool_check replaces check-auto-merge.sh with a stub that also logs
# the ISSUE_NUMBER it was invoked for, since the pool passes the PR number
# through the environment rather than as an argument.
function stub_pool_check() {
    local rc="${1:-0}"
    cat >"${STUB_DIR}/check-auto-merge.sh" <<EOF
#!/usr/bin/env bash
echo "stub check-auto-merge.sh ISSUE_NUMBER=\${ISSUE_NUMBER}" >>"\${MOCK_LOG}"
exit ${rc}
EOF
    chmod +x "${STUB_DIR}/check-auto-merge.sh"
}

begin_case "evaluates every pool PR oldest first, one at a time"
stub_pool_check
mkpool 5 7
run check-merge-pool.sh
assert_status 0
log_has_line "stub check-auto-merge.sh ISSUE_NUMBER=5"
log_has_line "stub check-auto-merge.sh ISSUE_NUMBER=7"
log_before "ISSUE_NUMBER=5" "ISSUE_NUMBER=7"
assert_out_has "Evaluating merge pool PR #5"
assert_out_has "Evaluating merge pool PR #7"

begin_case "a failing candidate does not stop the reconcile"
stub_pool_check 1
mkpool 5 7
run check-merge-pool.sh
assert_status 0
assert_out_has "Failed to evaluate merge pool PR #5"
log_has_line "stub check-auto-merge.sh ISSUE_NUMBER=7"

begin_case "does nothing when the merge pool is empty"
stub_pool_check
mkpool
run check-merge-pool.sh
assert_status 0
assert_out_has "The merge pool is empty."
log_lacks "stub"

begin_case "fails when the pool query fails"
stub_pool_check
export MOCK_GH_FAIL=1
run check-merge-pool.sh
assert_status 1
assert_out_has "Failed to list the merge pool."
log_lacks "stub"

begin_case "a candidate's stale owners state is cleared before evaluating it"
mkpool 5
export OWNERS_AREA_APPROVERS=". mallory"
cat >"${STUB_DIR}/check-auto-merge.sh" <<'EOF'
#!/usr/bin/env bash
echo "stub check-auto-merge.sh OWNERS_AREA_APPROVERS=${OWNERS_AREA_APPROVERS-unset}" >>"${MOCK_LOG}"
EOF
chmod +x "${STUB_DIR}/check-auto-merge.sh"
run check-merge-pool.sh
assert_status 0
log_has_line "stub check-auto-merge.sh OWNERS_AREA_APPROVERS=unset"

begin_case "a green pool PR reaches the merge through the real check"
stub approve-status.sh
stub pr-merge.sh
mkpool 9
mklabels "lgtm" "approved"
mkmergestate MERGEABLE "CI,test,COMPLETED,SUCCESS"
mkbehind 0
run check-merge-pool.sh
assert_status 0
assert_out_has "Evaluating merge pool PR #9"
assert_out_has "Auto-merging"
log_has "view 9 --json labels"
log_has_line "stub pr-merge.sh"
