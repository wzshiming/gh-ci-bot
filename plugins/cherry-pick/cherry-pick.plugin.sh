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

if ! pr="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json state,mergeCommit,title)"; then
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

# Check if the PR is merged
if [[ "$(jq -r '.state' <<<"${pr}")" != "MERGED" ]]; then
    echo "[FAIL] The PR must be merged before cherry-picking. Please merge the PR first."
    exit 1
fi

# Get the merge commit SHA
merge_commit="$(jq -r '.mergeCommit.oid // empty' <<<"${pr}")"
if [[ "${merge_commit}" == "" ]]; then
    echo "[FAIL] Could not find the merge commit for this PR."
    exit 1
fi

# Get the PR title
pr_title="$(jq -r '.title' <<<"${pr}")"

cherry_pick_branch="cherry-pick-${ISSUE_NUMBER}-to-${branch}"

# Clone the repository and perform the cherry-pick
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

# The token is in the URL, so git's output is only ever printed masked.
if ! out="$(git clone "https://x-access-token:${GH_TOKEN}@github.com/${GH_REPOSITORY}.git" "${tmpdir}" --branch "${branch}" 2>&1)"; then
    echo "${out//"${GH_TOKEN}"/***}"
    echo "[FAIL] Failed to clone the repository or branch \`${branch}\` does not exist."
    exit 1
fi

cd "${tmpdir}" || exit 1

git config user.email "github-actions[bot]@users.noreply.github.com"
git config user.name "github-actions[bot]"

# Configure the remote to use the authenticated URL
git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${GH_REPOSITORY}.git"

git checkout -b "${cherry_pick_branch}"

if ! parents="$(git rev-list --parents -n 1 "${merge_commit}")"; then
    echo "[FAIL] Could not find the merge commit ${merge_commit} in the repository."
    exit 1
fi

# rev-list prints the commit followed by its parents: 2+ parents is a merge commit.
if [[ "$(wc -w <<<"${parents}")" -gt 2 ]]; then
    echo "Merge commit: cherry-picking ${merge_commit} with -m 1"
    pick=(-m 1 "${merge_commit}")
else
    if ! commits="$(gh api --paginate "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/commits")"; then
        echo "[FAIL] Failed to get the commits of the pull request."
        exit 1
    fi
    # --paginate emits one array per page, so flatten before counting.
    messages="$(jq -s '[.[][].commit.message]' <<<"${commits}")"
    count="$(jq 'length' <<<"${messages}")"
    # A merged PR has at least one commit, so none means unusable data.
    if [[ "${count:-0}" -eq 0 ]] || ! jq -e 'all(.[]; type == "string")' <<<"${messages}" >/dev/null; then
        echo "[FAIL] Failed to get the commits of the pull request."
        exit 1
    fi
    # The endpoint lists at most 250 commits, so a longer list may be truncated.
    if [[ "${count}" -ge 250 ]]; then
        echo "[FAIL] The pull request has too many commits to cherry-pick automatically. Please cherry-pick manually."
        exit 1
    fi
    # A rebase merge leaves the PR's commits, messages verbatim, ending at the merge commit.
    rebased=false
    if [[ "${count}" -gt 1 ]]; then
        rebased=true
        for ((i = 0; i < count; i++)); do
            if ! message="$(git log -1 --format=%B "${merge_commit}~$((count - 1 - i))")"; then
                echo "[FAIL] Could not read the commits before ${merge_commit} in the repository."
                exit 1
            fi
            if [[ "${message}" != "$(jq -r ".[${i}]" <<<"${messages}")" ]]; then
                rebased=false
                break
            fi
        done
    fi
    if [[ "${rebased}" == true ]]; then
        echo "Rebase merge: cherry-picking ${count} commits up to ${merge_commit}"
        pick=("${merge_commit}~${count}..${merge_commit}")
    else
        echo "Squash merge or single commit: cherry-picking ${merge_commit}"
        pick=("${merge_commit}")
    fi
fi

git cherry-pick "${pick[@]}" || {
    echo "[FAIL] Cherry-pick failed due to conflicts. Please cherry-pick manually."
    exit 1
}

if ! out="$(git push origin "${cherry_pick_branch}" 2>&1)"; then
    echo "${out//"${GH_TOKEN}"/***}"
    echo "[FAIL] Failed to push the cherry-pick branch."
    exit 1
fi

# Create a new PR
gh pr create -R "${GH_REPOSITORY}" \
    --base "${branch}" \
    --head "${cherry_pick_branch}" \
    --title "[${branch}] ${pr_title}" \
    --body "Cherry-pick of #${ISSUE_NUMBER} to \`${branch}\`." || {
    echo "[FAIL] Failed to create the cherry-pick PR."
    exit 1
}
