#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

HOLD_LABEL="do-not-merge/hold"

# Prow-style: `/hold cancel` removes the hold label.
if [[ "${1:-}" == "cancel" ]]; then
    remove-labels.sh "${HOLD_LABEL}"
    exit $?
fi

add-labels.sh "${HOLD_LABEL}"
