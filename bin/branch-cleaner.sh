#!/usr/bin/env bash

# Delete the source branch of a merged PR, mirroring prow's branchcleaner
# plugin. Only branches living in the same repository as the PR are deleted;
# branches from forks and the repository's default branch are left untouched.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json state,isCrossRepository,headRefName)"

state="$(echo "${info}" | jq -r '.state')"
is_cross_repository="$(echo "${info}" | jq -r '.isCrossRepository')"
head_ref="$(echo "${info}" | jq -r '.headRefName')"

if [[ "${state}" != "MERGED" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} is not merged. Skipping branch cleanup."
    return 0 2>/dev/null || exit 0
fi

if [[ "${is_cross_repository}" == "true" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} source branch belongs to a fork. Skipping branch cleanup."
    return 0 2>/dev/null || exit 0
fi

default_branch="$(gh repo view "${GH_REPOSITORY}" --json defaultBranchRef --jq '.defaultBranchRef.name')"
if [[ -z "${head_ref}" || "${head_ref}" == "${default_branch}" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} source branch is the default branch. Skipping branch cleanup."
    return 0 2>/dev/null || exit 0
fi

echo "Deleting branch '${head_ref}' of merged PR ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh api -X DELETE "repos/${GH_REPOSITORY}/git/refs/heads/${head_ref}" ||
    echo "Failed to delete branch '${head_ref}'. It may have already been deleted."
