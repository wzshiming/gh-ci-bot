#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

if [[ "${LOGIN}" == "${AUTHOR}" ]]; then
    echo "[FAIL] You cannot approve your own PR. Please ask another reviewer to approve it."
    exit 1
fi

add-labels.sh approved

check-auto-merge.sh
