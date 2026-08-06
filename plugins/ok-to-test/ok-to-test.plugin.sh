#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

add-labels.sh ok-to-test

labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

if grep -qxF "needs-ok-to-test" <<<"${labels}"; then
    remove-labels.sh needs-ok-to-test
fi
