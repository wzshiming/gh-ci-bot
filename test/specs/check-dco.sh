#!/usr/bin/env bash

# DCO enforcement (#80), mirroring prow's dco plugin: check-dco.sh syncs
# the dco-signoff labels from the signoff state of the PR's commits and
# manages the instruction comment, /check-dco re-runs the check, the
# labels are allowlisted in ensure-labels.sh, and entrypoint.sh runs the
# check when the commits can have changed.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

YES_LABEL="dco-signoff: yes"
NO_LABEL="dco-signoff: no"
DCO_MARKER="Thanks for your pull request. Before we can look at it, you'll need to add a 'DCO signoff' to your commits."

SIGNED_MSG=$'Fix the fonts\n\nSigned-off-by: Bob <bob@example.com>'
UNSIGNED_MSG='Fix the fonts'

# stub_dco_scripts swaps the label and comment helpers for logging no-ops,
# so check-dco.sh is exercised in isolation and the log records exactly
# which labels and comments it wanted to change.
function stub_dco_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub comment.sh
}

# --- check-dco.sh: sync the labels and the comment on the PR ------------

begin_case "check-dco.sh: does nothing unless DCO_REQUIRED is set"
stub_dco_scripts
run check-dco.sh
assert_status 0
log_empty

begin_case "check-dco.sh: does nothing for issues"
export DCO_REQUIRED=1
export ISSUE_KIND="issue"
stub_dco_scripts
run check-dco.sh
assert_status 0
log_empty

begin_case "check-dco.sh: never mutates labels when the commits query fails"
export DCO_REQUIRED=1
export MOCK_GH_FAIL=1
stub_dco_scripts
run check-dco.sh
assert_status 0
assert_out_has "Failed to get the pull request commits"
log_has "/pulls/1/commits"
log_lacks "stub"

begin_case "check-dco.sh: never mutates labels when the labels query fails"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${SIGNED_MSG}"
run check-dco.sh
assert_status 0
assert_out_has "Failed to get the pull request labels"
log_lacks "stub"

begin_case "check-dco.sh: labels an all-signed PR dco-signoff: yes"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${SIGNED_MSG}" "def5678901" "${SIGNED_MSG}"
mklabels
run check-dco.sh
assert_status 0
assert_out_has "All commits have Signed-off-by."
log_has_line "stub add-labels.sh ${YES_LABEL}"
log_lacks "stub remove-labels.sh"
log_lacks "stub comment.sh"
log_lacks "DELETE"

begin_case "check-dco.sh: leaves a correctly labeled signed PR alone"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${SIGNED_MSG}"
mklabels "${YES_LABEL}" "kind/bug"
run check-dco.sh
assert_status 0
log_lacks "stub"
log_lacks "DELETE"

begin_case "check-dco.sh: signoffs arriving swap the labels and delete only the stale bot comment"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${SIGNED_MSG}"
mklabels "${NO_LABEL}"
mkissuecomments \
    "mock-bot" "${DCO_MARKER} Old list of commits." \
    "alice" "${DCO_MARKER} A human quoting the bot." \
    "mock-bot" "An unrelated bot comment."
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${YES_LABEL}"
log_has_line "stub remove-labels.sh ${NO_LABEL}"
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/issues/comments/1"
log_lacks "comments/2"
log_lacks "comments/3"
log_lacks "stub comment.sh"

begin_case "check-dco.sh: adds dco-signoff: no and comments on an unsigned commit"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${UNSIGNED_MSG}"
mklabels
run check-dco.sh
assert_status 0
assert_out_has "Commits in PR missing Signed-off-by."
log_has_line "stub add-labels.sh ${NO_LABEL}"
log_lacks "stub remove-labels.sh"
log_has "stub comment.sh ${DCO_MARKER}"
log_has "- [abc1234](https://github.com/wzshiming/example/commit/abc1234567) Fix the fonts"
log_has "https://github.com/wzshiming/example/blob/main/CONTRIBUTING.md"
log_has "developercertificate.org"

begin_case "check-dco.sh: lists only the commits missing a signoff"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${SIGNED_MSG}" "def5678901" "${UNSIGNED_MSG}"
mklabels
run check-dco.sh
assert_status 0
log_has "- [def5678]"
log_lacks "- [abc1234]"

begin_case "check-dco.sh: a push losing the signoff swaps the labels and comments"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${UNSIGNED_MSG}"
mklabels "${YES_LABEL}"
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${NO_LABEL}"
log_has_line "stub remove-labels.sh ${YES_LABEL}"
log_has "stub comment.sh ${DCO_MARKER}"

begin_case "check-dco.sh: an unsigned push replaces the previous comment without label edits"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "abc1234567" "${UNSIGNED_MSG}"
mklabels "${NO_LABEL}"
mkissuecomments "mock-bot" "${DCO_MARKER} Old list of commits."
run check-dco.sh
assert_status 0
log_lacks "stub add-labels.sh"
log_lacks "stub remove-labels.sh"
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/issues/comments/1"
log_has "stub comment.sh ${DCO_MARKER}"
log_before "DELETE" "stub comment.sh"

begin_case "check-dco.sh: merge commits are exempt"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "merge:aaa1111222" "Merge branch 'main' into feature" "bbb2222333" "${SIGNED_MSG}"
mklabels
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${YES_LABEL}"
log_lacks "stub comment.sh"

begin_case "check-dco.sh: a lowercase signoff counts"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "ccc3333444" $'Fix the fonts\n\nsigned-off-by: Bob <bob@example.com>'
mklabels
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${YES_LABEL}"

begin_case "check-dco.sh: an indented signoff does not count"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "ddd4444555" $'Fix the fonts\n\n  Signed-off-by: Bob <bob@example.com>'
mklabels
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${NO_LABEL}"

begin_case "check-dco.sh: a signoff in the middle of a line does not count"
export DCO_REQUIRED=1
stub_dco_scripts
mkcommits "eee5555666" "Fix Signed-off-by: Bob <bob@example.com>"
mklabels
run check-dco.sh
assert_status 0
log_has_line "stub add-labels.sh ${NO_LABEL}"

# --- /check-dco: the command --------------------------------------------

CHECK_DCO_PLUGIN="${PLUGINS_DIR}/check-dco/check-dco.plugin.sh"

begin_case "/check-dco: is only available on pull requests"
export DCO_REQUIRED=1
export ISSUE_KIND="issue"
stub check-dco.sh
run "${CHECK_DCO_PLUGIN}"
assert_status 1
assert_out_has "[FAIL] This command is only available on pull requests"
log_empty

begin_case "/check-dco: reports when the DCO check is not enabled"
stub check-dco.sh
run "${CHECK_DCO_PLUGIN}"
assert_status 1
assert_out_has "[FAIL] The DCO check is not enabled for this repository."
log_empty

begin_case "/check-dco: re-runs the DCO check"
export DCO_REQUIRED=1
stub check-dco.sh
run "${CHECK_DCO_PLUGIN}"
assert_status 0
log_has_line "stub check-dco.sh"

begin_case "/check-dco: full stack, labels an unsigned PR via gh"
export DCO_REQUIRED=1
mkcommits "abc1234567" "${UNSIGNED_MSG}"
mklabels
run "${CHECK_DCO_PLUGIN}"
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${NO_LABEL}"
log_has "comment 1 --body ${DCO_MARKER}"

# --- ensure-labels.sh: the label creation allowlist ---------------------

begin_case "ensure-labels.sh: creates the dco-signoff labels with their colors and descriptions"
mkrepolabels
run ensure-labels.sh "${YES_LABEL}" "${NO_LABEL}"
assert_status 0
log_has "create ${YES_LABEL} --color bfe5bf"
log_has "has DCO signed all their commits."
log_has "create ${NO_LABEL} --color e11d21"
log_has "has not DCO signed all their commits."

# --- entrypoint.sh: when the DCO check runs -----------------------------

begin_case "entrypoint.sh: TYPE=synchronize runs the DCO check"
export TYPE="synchronize"
export DCO_REQUIRED=1
# Disable the matching-labels sync so the label edits stay focused.
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a feature"
mksize 1 0
mklabels
mkcommits "abc1234567" "${UNSIGNED_MSG}"
run "${ENTRYPOINT}"
assert_status 0
log_has "/pulls/1/commits"
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${NO_LABEL}"
log_has "comment 1 --body ${DCO_MARKER}"

begin_case "entrypoint.sh: TYPE=synchronize leaves the DCO alone when the gate is off"
export TYPE="synchronize"
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a feature"
mksize 1 0
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_lacks "/pulls/1/commits"
log_lacks "--add-label ${NO_LABEL}"

begin_case "entrypoint.sh: TYPE=edited does not run the DCO check"
export TYPE="edited"
export DCO_REQUIRED=1
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a feature"
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_lacks "/pulls/1/commits"
