#!/usr/bin/env bash

# check-size.sh: the size/* label follows the PR's total changed lines
# (additions + deletions), mirroring prow's size plugin.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
}

# sizes <description> <additions> <deletions> <expected-label>: an
# unlabeled PR with the given diff gets the expected size label.
function sizes() {
    begin_case "${1}"
    stub_label_scripts
    mksize "${2}" "${3}"
    run check-size.sh
    assert_status 0
    assert_out_has "PR changes $((${2} + ${3})) lines, size label: ${4}"
    log_has_line "stub add-labels.sh ${4}"
    log_lacks "stub remove-labels.sh"
}

sizes "an empty diff is size/XS" 0 0 "size/XS"
sizes "9 changed lines are size/XS" 4 5 "size/XS"
sizes "10 changed lines are size/S" 10 0 "size/S"
sizes "29 changed lines are size/S" 14 15 "size/S"
sizes "42 changed lines are size/M" 21 21 "size/M"
sizes "350 changed lines are size/L" 100 250 "size/L"
sizes "999 changed lines are size/XL" 499 500 "size/XL"
sizes "1500 changed lines are size/XXL" 1000 500 "size/XXL"

begin_case "leaves a correctly labeled PR alone"
stub_label_scripts
mksize 21 21 "size/M" "kind/bug"
run check-size.sh
assert_status 0
log_has "view 1 --json additions,deletions,labels"
log_lacks "stub"

begin_case "replaces a stale size label"
stub_label_scripts
mksize 21 21 "size/S"
run check-size.sh
assert_status 0
log_has_line "stub remove-labels.sh size/S"
log_has_line "stub add-labels.sh size/M"

begin_case "removes every stale size label"
stub_label_scripts
mksize 21 21 "size/S" "size/XL"
run check-size.sh
assert_status 0
log_has_line "stub remove-labels.sh size/S"
log_has_line "stub remove-labels.sh size/XL"
log_has_line "stub add-labels.sh size/M"

begin_case "does not touch non-size labels"
stub_label_scripts
mksize 21 21 "size/S" "kind/bug" "lgtm"
run check-size.sh
assert_status 0
log_lacks "kind/bug"
log_lacks "lgtm"

begin_case "does nothing for issues"
stub_label_scripts
export ISSUE_KIND="issue"
run check-size.sh
assert_status 0
log_empty

begin_case "full stack: really swaps the labels via gh"
mksize 100 250 "size/M"
run check-size.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --remove-label size/M"
log_has_line "gh pr -R wzshiming/example edit 1 --add-label size/L"

begin_case "never mutates labels when the PR query fails"
stub_label_scripts
export MOCK_GH_FAIL=1
run check-size.sh
assert_status 0
assert_out_has "skipping"
log_lacks "stub"

begin_case "never mutates labels when the changed-line count is not a number"
stub_label_scripts
mksize null null
run check-size.sh
assert_status 0
assert_out_has "skipping"
log_lacks "stub"
