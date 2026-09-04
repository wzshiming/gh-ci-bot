#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

# A fork's branch cannot be targeted by workflow_dispatch, so it is passed as empty.
if ! head="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json headRefName,isCrossRepository --jq 'if .isCrossRepository then "" else .headRefName end')"; then
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

if ! gh pr -R "${GH_REPOSITORY}" update-branch "${ISSUE_NUMBER}" --rebase; then
    echo "[FAIL] Failed to rebase the branch. The branch may have conflicts that need to be resolved manually."
    exit 1
fi

dispatch-workflows.sh synchronize "${head}"
