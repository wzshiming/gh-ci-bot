#!/usr/bin/env bash

# Prow-style; GitHub has no "not planned" close reason for pull requests.
if [[ "${1:-}" == "not-planned" ]]; then
    if [[ "${ISSUE_KIND}" == "pr" ]]; then
        echo '[FAIL] PRs cannot be closed as "Not Planned".'
        exit 1
    fi
    gh issue -R "${GH_REPOSITORY}" close "${ISSUE_NUMBER}" --reason "not planned"
    exit $?
fi

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" close "${ISSUE_NUMBER}"
