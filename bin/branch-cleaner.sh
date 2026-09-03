#!/usr/bin/env bash

# Delete the source branch of a merged PR when the branch lives in the
# same repository, mirroring prow's branchcleaner plugin. Fork branches
# are never touched, PRs closed without merging keep their branch, and
# the repository's default branch is never deleted. The cleanup is
# best-effort: it only logs, never posts comments, and always exits 0 so
# a failed cleanup cannot fail the merge that triggered it.
#
# Opt-in: does nothing unless the BRANCH_CLEANER environment variable is
# set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${BRANCH_CLEANER:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Fail open: never delete a branch from missing PR data.
if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json headRefName,isCrossRepository,state)"; then
    echo "Failed to get the pull request, skipping the branch cleanup."
    return 0 2>/dev/null || exit 0
fi

state="$(echo "${info}" | jq -r '.state')"
cross_repository="$(echo "${info}" | jq -r '.isCrossRepository')"
head_branch="$(echo "${info}" | jq -r '.headRefName')"

if [[ "${state}" != "MERGED" ]]; then
    echo "PR is not merged, skipping the branch cleanup."
    return 0 2>/dev/null || exit 0
fi

if [[ "${cross_repository}" != "false" ]]; then
    echo "PR source branch '${head_branch}' belongs to a fork, skipping the branch cleanup."
    return 0 2>/dev/null || exit 0
fi

default_branch="$(gh api "/repos/${GH_REPOSITORY}" | jq -r '.default_branch')"
if [[ -z "${head_branch}" || "${head_branch}" == "${default_branch}" ]]; then
    echo "PR source branch '${head_branch}' is the default branch, skipping the branch cleanup."
    return 0 2>/dev/null || exit 0
fi

if gh api --silent -X DELETE "/repos/${GH_REPOSITORY}/git/refs/heads/${head_branch}"; then
    echo "Deleted source branch '${head_branch}' of the merged PR."
else
    # The branch may be protected or already deleted (e.g. by GitHub's
    # own head-branch auto-deletion); the merge already happened, so
    # a failed cleanup is only logged.
    echo "Failed to delete source branch '${head_branch}', skipping the branch cleanup."
fi

return 0 2>/dev/null || exit 0
