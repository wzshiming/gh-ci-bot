#!/usr/bin/env bash

# /ok-to-test - Approve the workflow runs of a PR that are awaiting approval
# from a maintainer (e.g. runs from public forks of first-time contributors),
# mirroring prow's ok-to-test plugin. The "ok-to-test" label is applied so
# that runs of future pushes to the PR are approved automatically.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

OK_TO_TEST_LABEL="ok-to-test"

# Make sure the label exists so adding it cannot fail.
if ! gh label -R "${GH_REPOSITORY}" list --search "${OK_TO_TEST_LABEL}" --json name --jq '.[].name' | grep -qx "${OK_TO_TEST_LABEL}"; then
    gh label -R "${GH_REPOSITORY}" create "${OK_TO_TEST_LABEL}" --color 15dd18 --description "Indicates that workflow runs of this PR are approved automatically." || true
fi

add-labels.sh "${OK_TO_TEST_LABEL}"

approve-workflows.sh
