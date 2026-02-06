#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

branch="${1:-}"

if [[ "${branch}" == "" ]]; then
    echo "[FAIL] Missing required argument: branch name. Usage: \`/base <branch>\`"
fi

gh -R "${GH_REPOSITORY}" pr edit "${ISSUE_NUMBER}" -B "${branch}" ||
    echo "[FAIL] Failed to change the base branch. Please verify the branch name exists and try again."
