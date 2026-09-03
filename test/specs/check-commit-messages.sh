#!/usr/bin/env bash

# check-commit-messages.sh: the do-not-merge/invalid-commit-message label
# follows the PR's commit messages and title, mirroring prow's
# invalidcommitmsg plugin: issue-closing keywords and @mentions are not
# allowed. Opt-in via BLOCK_INVALID_COMMIT_MESSAGES.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

INVALID_LABEL="do-not-merge/invalid-commit-message"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

begin_case "does nothing unless BLOCK_INVALID_COMMIT_MESSAGES is set"
stub_label_scripts
mkcommits "1:fixes #42"
run check-commit-messages.sh
assert_status 0
log_empty

begin_case "does nothing for issues"
export BLOCK_INVALID_COMMIT_MESSAGES=1
export ISSUE_KIND="issue"
stub_label_scripts
run check-commit-messages.sh
assert_status 0
log_empty

begin_case "labels a commit message with an issue-closing keyword"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Add a renderer" $'1:Add a flag\n\nfixes #42'
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
assert_out_has "A commit message contains"
log_has_line "stub add-labels.sh ${INVALID_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "the issue-closing keyword is case-insensitive"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Closes #42"
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_has_line "stub add-labels.sh ${INVALID_LABEL}"

begin_case "a colon after the keyword also counts"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Resolved: #42"
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_has_line "stub add-labels.sh ${INVALID_LABEL}"

begin_case "a cross-repository issue reference also counts"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:fix wzshiming/example#42"
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_has_line "stub add-labels.sh ${INVALID_LABEL}"

begin_case "labels a commit message with an @mention"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits $'1:Add a flag\n\nThanks @alice for the report'
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_has_line "stub add-labels.sh ${INVALID_LABEL}"

begin_case "an email address is not an @mention"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits $'1:Add a flag\n\nSigned-off-by: Alice <alice@example.com>'
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_lacks "stub"

begin_case "a keyword without an issue number is fine"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:fix the renderer" "1:close the file after reading"
mktitle "fix the renderer"
run check-commit-messages.sh
assert_status 0
log_lacks "stub"

begin_case "an issue number without a keyword is fine"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Add a flag, see #42"
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_lacks "stub"

begin_case "labels an invalid PR title even when the commits are clean"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Add a flag"
mktitle "Fixes #42"
run check-commit-messages.sh
assert_status 0
assert_out_has "The PR title contains"
log_has_line "stub add-labels.sh ${INVALID_LABEL}"

begin_case "leaves an already labeled invalid PR alone"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:fixes #42"
mktitle "Add a flag" "${INVALID_LABEL}"
run check-commit-messages.sh
assert_status 0
log_lacks "stub"

begin_case "removes the label once the messages and title are fixed"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Add a renderer"
mktitle "Add a renderer" "${INVALID_LABEL}" "kind/feature"
run check-commit-messages.sh
assert_status 0
log_has_line "stub remove-labels.sh ${INVALID_LABEL}"
log_lacks "stub add-labels.sh"

begin_case "leaves a valid unlabeled PR alone"
export BLOCK_INVALID_COMMIT_MESSAGES=1
stub_label_scripts
mkcommits "1:Add a renderer"
mktitle "Add a renderer" "kind/feature"
run check-commit-messages.sh
assert_status 0
log_lacks "stub"

begin_case "never mutates labels when the commits query fails"
export BLOCK_INVALID_COMMIT_MESSAGES=1
export MOCK_GH_FAIL=1
stub_label_scripts
run check-commit-messages.sh
assert_status 0
assert_out_has "Failed to get the pull request commits"
log_lacks "stub"

begin_case "full stack: really adds the label via gh"
export BLOCK_INVALID_COMMIT_MESSAGES=1
mkcommits "1:fixes #42"
mktitle "Add a flag"
run check-commit-messages.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${INVALID_LABEL}"

# --- entrypoint.sh: the dispatch ----------------------------------------

begin_case "entrypoint.sh: TYPE=synchronize syncs the commit-messages label"
export TYPE="synchronize"
export BLOCK_INVALID_COMMIT_MESSAGES=1
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a flag"
mksize 1 0
mkcommits "1:fixes #42"
mktitle "Add a flag"
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${INVALID_LABEL}"

begin_case "entrypoint.sh: TYPE=edited drops the label after a title fix"
export TYPE="edited"
export BLOCK_INVALID_COMMIT_MESSAGES=1
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a flag"
mkcommits "1:Add a flag"
mktitle "Add a flag" "${INVALID_LABEL}"
mklabels "${INVALID_LABEL}"
run "${ENTRYPOINT}"
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --remove-label ${INVALID_LABEL}"
