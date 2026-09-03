#!/usr/bin/env bash

# Sync the "do-not-merge/contains-merge-commits" label on a PR, mirroring
# prow's mergecommitblocker plugin: the label is added while the PR
# contains merge commits (commits with more than one parent), and removed
# once they are rebased away. Labels only: this script never posts
# comments.
#
# Opt-in: does nothing unless the BLOCK_MERGE_COMMITS environment
# variable is set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${BLOCK_MERGE_COMMITS:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

MERGE_COMMITS_LABEL="do-not-merge/contains-merge-commits"

# A commit with more than one parent is a merge commit.
if ! merge_commits="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/commits" \
    --jq '.[] | select((.parents | length) > 1) | .sha')"; then
    # Never mutate labels from missing commit data.
    echo "Failed to get the pull request commits, skipping the merge-commits sync."
    return 0 2>/dev/null || exit 0
fi

if ! labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"; then
    # Never mutate labels from missing PR data.
    echo "Failed to get the pull request, skipping the merge-commits sync."
    return 0 2>/dev/null || exit 0
fi

has_label=false
if grep -qxF "${MERGE_COMMITS_LABEL}" <<<"${labels}"; then
    has_label=true
fi

if [[ -n "${merge_commits}" ]]; then
    echo "PR contains merge commits:"
    while read -r sha; do
        if [[ -z "${sha}" ]]; then
            continue
        fi
        echo "- ${sha}"
    done <<<"${merge_commits}"
    if [[ "${has_label}" != "true" ]]; then
        add-labels.sh "${MERGE_COMMITS_LABEL}"
    fi
elif [[ "${has_label}" == "true" ]]; then
    remove-labels.sh "${MERGE_COMMITS_LABEL}"
fi
