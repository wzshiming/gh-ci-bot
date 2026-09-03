#!/usr/bin/env bash

# pr-merge.sh: do-not-merge/* and "dco-signoff: no" labels block merging,
# and a failed blocking-label query fails closed instead of merging blind.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "merges when no blocking labels are present"
mklabels "lgtm" "approved"
run pr-merge.sh
assert_status 0
assert_out_has "PR wzshiming/example#1 merge by alice"
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "refuses to merge when a do-not-merge label is present"
mklabels "do-not-merge/hold"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`do-not-merge/hold\`."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "refuses to merge when the dco-signoff: no label is present"
mklabels "lgtm" "dco-signoff: no"
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`dco-signoff: no\`."
log_lacks "gh pr -R wzshiming/example merge"

begin_case "the dco-signoff: yes label does not block merging"
mklabels "dco-signoff: yes"
run pr-merge.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example merge 1 --merge"

begin_case "fails closed when the blocking-label query fails"
export MOCK_GH_FAIL=1
run pr-merge.sh
assert_status 1
assert_out_has "[FAIL] Failed to check for blocking labels, not merging."
log_lacks "gh pr -R wzshiming/example merge"
