#!/usr/bin/env bash

# check-matching-labels.sh: needs-* labels follow the configured
# rules, mirroring prow's require-matching-label plugin.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
}

begin_case "adds needs-kind to a PR without a kind label (default rule)"
stub_label_scripts
mklabels "lgtm"
run check-matching-labels.sh
assert_status 0
assert_out_has "No label matching \`^kind/\`, adding needs-kind"
log_has_line "stub add-labels.sh needs-kind"
log_lacks "stub remove-labels.sh"

begin_case "leaves a PR with a kind label alone"
stub_label_scripts
mklabels "kind/bug"
run check-matching-labels.sh
assert_status 0
log_has "view 1 --json labels"
log_lacks "stub"

begin_case "removes needs-kind once a kind label is added"
stub_label_scripts
mklabels "kind/bug" "needs-kind"
run check-matching-labels.sh
assert_status 0
assert_out_has "Found a label matching \`^kind/\`, removing needs-kind"
log_has_line "stub remove-labels.sh needs-kind"
log_lacks "stub add-labels.sh"

begin_case "leaves needs-kind alone while no kind label exists"
stub_label_scripts
mklabels "needs-kind" "lgtm"
run check-matching-labels.sh
assert_status 0
log_lacks "stub"

begin_case "an empty PR_REQUIRE_MATCHING_LABELS disables the check"
stub_label_scripts
export PR_REQUIRE_MATCHING_LABELS=""
mklabels
run check-matching-labels.sh
assert_status 0
log_empty

begin_case "applies every configured rule"
stub_label_scripts
export PR_REQUIRE_MATCHING_LABELS=$'needs-kind ^kind/\nneeds-priority ^priority/'
mklabels "kind/bug" "needs-kind"
run check-matching-labels.sh
assert_status 0
log_has_line "stub remove-labels.sh needs-kind"
log_has_line "stub add-labels.sh needs-priority"

begin_case "issues use the issue rules and the gh issue command"
stub_label_scripts
export ISSUE_KIND="issue"
export ISSUE_REQUIRE_MATCHING_LABELS="needs-triage ^triage/"
mklabels
run check-matching-labels.sh
assert_status 0
log_has "gh issue -R wzshiming/example view 1 --json labels"
log_has_line "stub add-labels.sh needs-triage"

begin_case "empty issue rules disable the check even when PR rules are set"
stub_label_scripts
export ISSUE_KIND="issue"
export ISSUE_REQUIRE_MATCHING_LABELS=""
export PR_REQUIRE_MATCHING_LABELS="needs-kind ^kind/"
mklabels
run check-matching-labels.sh
assert_status 0
log_empty

begin_case "a rule without a regexp is skipped"
stub_label_scripts
export PR_REQUIRE_MATCHING_LABELS="needs-kind"
mklabels
run check-matching-labels.sh
assert_status 0
log_has "view 1 --json labels"
log_lacks "stub"

begin_case "full stack: really adds needs-kind via gh"
mklabels
mkrepolabels "needs-kind"
run check-matching-labels.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label needs-kind"

begin_case "never mutates labels when the label query fails"
stub_label_scripts
export MOCK_GH_FAIL=1
run check-matching-labels.sh
assert_status 0
assert_out_has "skipping"
log_lacks "stub"
