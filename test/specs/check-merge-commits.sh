#!/usr/bin/env bash

# check-merge-commits.sh: the do-not-merge/contains-merge-commits label
# follows the PR's merge commits, mirroring prow's mergecommitblocker
# plugin. Opt-in via BLOCK_MERGE_COMMITS.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

MERGE_COMMITS_LABEL="do-not-merge/contains-merge-commits"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

begin_case "does nothing unless BLOCK_MERGE_COMMITS is set"
stub_label_scripts
mkcommits "2:Merge branch 'main' into feature"
run check-merge-commits.sh
assert_status 0
log_empty

begin_case "does nothing for issues"
export BLOCK_MERGE_COMMITS=1
export ISSUE_KIND="issue"
stub_label_scripts
run check-merge-commits.sh
assert_status 0
log_empty

begin_case "labels a PR containing a merge commit"
export BLOCK_MERGE_COMMITS=1
stub_label_scripts
mkcommits "1:Add a renderer" "2:Merge branch 'main' into feature"
mklabels "kind/feature"
run check-merge-commits.sh
assert_status 0
assert_out_has "PR contains merge commits:"
assert_out_has "- sha-2"
log_has_line "stub add-labels.sh ${MERGE_COMMITS_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "leaves an already labeled PR with merge commits alone"
export BLOCK_MERGE_COMMITS=1
stub_label_scripts
mkcommits "2:Merge branch 'main' into feature"
mklabels "${MERGE_COMMITS_LABEL}"
run check-merge-commits.sh
assert_status 0
log_lacks "stub"

begin_case "removes the label once the merge commits are rebased away"
export BLOCK_MERGE_COMMITS=1
stub_label_scripts
mkcommits "1:Add a renderer" "1:Add a flag"
mklabels "${MERGE_COMMITS_LABEL}" "kind/feature"
run check-merge-commits.sh
assert_status 0
log_has_line "stub remove-labels.sh ${MERGE_COMMITS_LABEL}"
log_lacks "stub add-labels.sh"

begin_case "leaves a clean unlabeled PR alone"
export BLOCK_MERGE_COMMITS=1
stub_label_scripts
mkcommits "1:Add a renderer"
mklabels "kind/feature"
run check-merge-commits.sh
assert_status 0
log_lacks "stub"

begin_case "a label merely prefixed with the label does not count as labeled"
export BLOCK_MERGE_COMMITS=1
stub_label_scripts
mkcommits "2:Merge branch 'main' into feature"
mklabels "${MERGE_COMMITS_LABEL}-docs"
run check-merge-commits.sh
assert_status 0
log_has_line "stub add-labels.sh ${MERGE_COMMITS_LABEL}"

begin_case "never mutates labels when the commits query fails"
export BLOCK_MERGE_COMMITS=1
export MOCK_GH_FAIL=1
stub_label_scripts
run check-merge-commits.sh
assert_status 0
assert_out_has "Failed to get the pull request commits"
log_lacks "stub"

begin_case "full stack: really adds the label via gh"
export BLOCK_MERGE_COMMITS=1
mkcommits "2:Merge branch 'main' into feature"
mklabels
run check-merge-commits.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${MERGE_COMMITS_LABEL}"

# --- entrypoint.sh: the dispatch ----------------------------------------

begin_case "entrypoint.sh: TYPE=synchronize syncs the merge-commits label"
export TYPE="synchronize"
export BLOCK_MERGE_COMMITS=1
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a renderer"
mksize 1 0
mkcommits "2:Merge branch 'main' into feature"
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${MERGE_COMMITS_LABEL}"

begin_case "entrypoint.sh: TYPE=edited does not check merge commits (they cannot change)"
export TYPE="edited"
export BLOCK_MERGE_COMMITS=1
export PR_REQUIRE_MATCHING_LABELS=""
mkwip false "Add a renderer"
mkcommits "2:Merge branch 'main' into feature"
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_lacks "/commits"
log_lacks "--add-label ${MERGE_COMMITS_LABEL}"
