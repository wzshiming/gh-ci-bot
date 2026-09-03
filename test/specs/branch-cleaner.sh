#!/usr/bin/env bash

# branch-cleaner.sh: when BRANCH_CLEANER is set, the source branch of a
# merged same-repo PR is deleted (prow's branchcleaner plugin). Fork
# branches, unmerged PRs and the default branch are never touched, and
# every skip or failure exits 0 so a cleanup can never fail a merge.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

begin_case "deletes the source branch of a merged same-repo PR"
export BRANCH_CLEANER="true"
mkbranch MERGED false feature-x
run branch-cleaner.sh
assert_status 0
assert_out_has "Deleted source branch 'feature-x' of the merged PR."
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/git/refs/heads/feature-x"

begin_case "branch names with slashes are deleted as-is"
export BRANCH_CLEANER="true"
mkbranch MERGED false feature/foo
run branch-cleaner.sh
assert_status 0
log_has_line "gh api --silent -X DELETE /repos/wzshiming/example/git/refs/heads/feature/foo"

begin_case "does nothing unless BRANCH_CLEANER is set"
mkbranch MERGED false feature-x
run branch-cleaner.sh
assert_status 0
log_empty

begin_case "a PR closed without merging keeps its branch"
export BRANCH_CLEANER="true"
mkbranch CLOSED false feature-x
run branch-cleaner.sh
assert_status 0
assert_out_has "PR is not merged, skipping the branch cleanup."
log_lacks "DELETE"

begin_case "an open PR keeps its branch"
export BRANCH_CLEANER="true"
mkbranch OPEN false feature-x
run branch-cleaner.sh
assert_status 0
log_lacks "DELETE"

begin_case "never touches a fork branch"
export BRANCH_CLEANER="true"
mkbranch MERGED true feature-x
run branch-cleaner.sh
assert_status 0
assert_out_has "belongs to a fork, skipping the branch cleanup."
log_lacks "DELETE"

begin_case "never deletes the default branch"
export BRANCH_CLEANER="true"
mkbranch MERGED false main
run branch-cleaner.sh
assert_status 0
assert_out_has "is the default branch, skipping the branch cleanup."
log_lacks "DELETE"

begin_case "fails open when the PR query fails"
export BRANCH_CLEANER="true"
export MOCK_GH_FAIL=1
run branch-cleaner.sh
assert_status 0
assert_out_has "Failed to get the pull request, skipping the branch cleanup."
log_lacks "DELETE"

begin_case "does nothing for issues"
export BRANCH_CLEANER="true"
export ISSUE_KIND="issue"
run branch-cleaner.sh
assert_status 0
log_empty
