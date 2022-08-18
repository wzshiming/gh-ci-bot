#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

branch="${1:-}"

if [[ "${branch}" == "" ]]; then
    echo "[FAIL] Need a branch"
fi

gh -R "${GH_REPOSITORY}" pr edit "${ISSUE_NUMBER}" -B "${branch}" ||
    echo "[FAIL] Failed change base"
