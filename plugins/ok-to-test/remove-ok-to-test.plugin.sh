#!/usr/bin/env bash

# /remove-ok-to-test - Remove the "ok-to-test" label so workflow runs of
# future pushes to the PR are no longer approved automatically.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

remove-labels.sh ok-to-test
