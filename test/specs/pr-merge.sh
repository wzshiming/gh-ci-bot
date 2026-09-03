#!/usr/bin/env bash

# pr-merge.sh: do-not-merge/* labels block merging, a failed
# blocking-label query fails closed instead of merging blind, and a
# successful merge runs the branch cleaner in the same run (merges made
# with GITHUB_TOKEN trigger no closed event run).

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "merges when no blocking labels are present"
mklabels "lgtm" "approved"
run pr-merge.sh
assert_status 0
assert_out_has "PR wzshiming/example#1 merge by alice"
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "a successful merge runs the branch cleaner"
stub branch-cleaner.sh
mklabels "lgtm" "approved"
run pr-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --merge"
log_has_line "stub branch-cleaner.sh"
log_before "merge 1 --merge" "stub branch-cleaner.sh"

begin_case "refuses to merge when a do-not-merge label is present"
stub branch-cleaner.sh
mklabels "do-not-merge/hold"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`do-not-merge/hold\`."
log_lacks "gh pr -R wzshiming/example merge"
log_lacks "stub branch-cleaner.sh"

begin_case "fails closed when the blocking-label query fails"
export MOCK_GH_FAIL=1
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] Failed to check for blocking labels, not merging."
log_lacks "gh pr -R wzshiming/example merge"
