#!/usr/bin/env bash

# Delete the source branch of a merged PR, like prow's branchcleaner plugin.
# Only branches in the same repository are deleted, never forks.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

pr_info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json state,isCrossRepository,headRefName,baseRefName)"

state="$(echo "${pr_info}" | jq -r '.state')"
is_cross_repository="$(echo "${pr_info}" | jq -r '.isCrossRepository')"
head_ref="$(echo "${pr_info}" | jq -r '.headRefName')"
base_ref="$(echo "${pr_info}" | jq -r '.baseRefName')"

if [[ "${state}" != "MERGED" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} is not merged, skipping branch cleanup"
    return 0 2>/dev/null || exit 0
fi

if [[ "${is_cross_repository}" == "true" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} is from a fork, skipping branch cleanup"
    return 0 2>/dev/null || exit 0
fi

if [[ "${head_ref}" == "" || "${head_ref}" == "null" || "${head_ref}" == "${base_ref}" ]]; then
    echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} has no deletable source branch, skipping branch cleanup"
    return 0 2>/dev/null || exit 0
fi

echo "Deleting source branch '${head_ref}' of merged PR ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh api -X DELETE "repos/${GH_REPOSITORY}/git/refs/heads/${head_ref}" ||
    echo "Failed to delete branch '${head_ref}'. It may have already been deleted or be protected."
