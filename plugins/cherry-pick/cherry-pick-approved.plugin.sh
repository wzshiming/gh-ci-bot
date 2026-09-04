#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

APPROVED_LABEL="cherry-pick-approved"
UNAPPROVED_LABEL="do-not-merge/cherry-pick-not-approved"

if ! labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"; then
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

# Prow-style: `cancel` only drops the approval; the label sync re-blocks the PR.
if [[ "${1:-}" == "cancel" ]]; then
    if grep -qxF "${APPROVED_LABEL}" <<<"${labels}"; then
        remove-labels.sh "${APPROVED_LABEL}"
    fi
    exit 0
fi

if ! grep -qxF "${APPROVED_LABEL}" <<<"${labels}"; then
    add-labels.sh "${APPROVED_LABEL}"
fi
if grep -qxF "${UNAPPROVED_LABEL}" <<<"${labels}"; then
    remove-labels.sh "${UNAPPROVED_LABEL}"
fi
