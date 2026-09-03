#!/usr/bin/env bash

# Disarm GitHub's auto-merge on a PR that carries a do-not-merge/* label:
# pr-merge.sh falls back to `gh pr merge --auto` while checks are pending, and
# GitHub keeps that queued merge armed when a blocking label arrives later.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json autoMergeRequest,labels)"; then
    echo "[FAIL] Failed to check whether auto-merge is enabled. If the PR is queued for auto-merge, disable it manually."
    exit 1
fi

queued="$(echo "${info}" | jq -r '.autoMergeRequest != null')"
if [[ "${queued}" != "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

blocking_labels="$(echo "${info}" | jq -r '[.labels[].name | select(startswith("do-not-merge/"))] | join("`, `")')"
if [[ -z "${blocking_labels}" ]]; then
    return 0 2>/dev/null || exit 0
fi

echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} is queued for auto-merge despite \`${blocking_labels}\`, disabling auto-merge"
gh pr -R "${GH_REPOSITORY}" merge "${ISSUE_NUMBER}" --disable-auto ||
    echo "[FAIL] Failed to disable auto-merge; the PR is still queued to merge despite \`${blocking_labels}\`."
