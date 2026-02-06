#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

gh pr -R "${GH_REPOSITORY}" update-branch ${ISSUE_NUMBER} --rebase ||
    echo "[FAIL] Failed to rebase the branch. The branch may have conflicts that need to be resolved manually."
