#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

# Prow-style: `/lgtm cancel` removes the label, the PR author included.
if [[ "${1:-}" == "cancel" ]]; then
    remove-labels.sh lgtm
    exit $?
fi

if [[ "${LOGIN}" == "${AUTHOR}" ]]; then
    echo "[FAIL] You cannot LGTM your own PR. Please ask another reviewer to approve it."
    exit 1
fi

add-labels.sh lgtm
