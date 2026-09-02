#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

OK_TO_TEST_LABEL="ok-to-test"
NEEDS_OK_TO_TEST_LABEL="needs-ok-to-test"

if ! labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"; then
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

if ! grep -qxF "${OK_TO_TEST_LABEL}" <<<"${labels}"; then
    add-labels.sh "${OK_TO_TEST_LABEL}"
fi
if grep -qxF "${NEEDS_OK_TO_TEST_LABEL}" <<<"${labels}"; then
    remove-labels.sh "${NEEDS_OK_TO_TEST_LABEL}"
fi

approve-workflow-runs.sh
