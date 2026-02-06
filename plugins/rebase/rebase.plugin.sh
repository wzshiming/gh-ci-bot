#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

gh pr -R "${GH_REPOSITORY}" update-branch ${ISSUE_NUMBER} --rebase ||
    echo "[FAIL] Failed rebase branch"
