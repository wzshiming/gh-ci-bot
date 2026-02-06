#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

branch="${1:-}"

if [[ "${branch}" == "" ]]; then
    echo "[FAIL] Missing required argument: branch name. Usage: \`/cherry-pick <branch>\`"
    exit 1
fi

# Check if the PR is merged
merged="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json merged --jq '.merged')"
if [[ "${merged}" != "true" ]]; then
    echo "[FAIL] The PR must be merged before cherry-picking. Please merge the PR first."
    exit 1
fi

# Get the merge commit SHA
merge_commit="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json mergeCommit --jq '.mergeCommit.oid')"
if [[ "${merge_commit}" == "" || "${merge_commit}" == "null" ]]; then
    echo "[FAIL] Could not find the merge commit for this PR."
    exit 1
fi

# Get the PR title
pr_title="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json title --jq '.title')"

cherry_pick_branch="cherry-pick-${ISSUE_NUMBER}-to-${branch}"

# Clone the repository and perform the cherry-pick
tmpdir="$(mktemp -d)"
trap 'rm -rf ${tmpdir}' EXIT

gh repo clone "${GH_REPOSITORY}" "${tmpdir}" -- -b "${branch}" || {
    echo "[FAIL] Failed to clone the repository or branch \`${branch}\` does not exist."
    exit 1
}

cd "${tmpdir}" || exit 1
git checkout -b "${cherry_pick_branch}"
git cherry-pick "${merge_commit}" -m 1 || {
    echo "[FAIL] Cherry-pick failed due to conflicts. Please cherry-pick manually."
    exit 1
}
git push origin "${cherry_pick_branch}" || {
    echo "[FAIL] Failed to push the cherry-pick branch."
    exit 1
}

# Create a new PR
gh pr create -R "${GH_REPOSITORY}" \
    --base "${branch}" \
    --head "${cherry_pick_branch}" \
    --title "[${branch}] ${pr_title}" \
    --body "Cherry-pick of #${ISSUE_NUMBER} to \`${branch}\`." || {
    echo "[FAIL] Failed to create the cherry-pick PR."
    exit 1
}
