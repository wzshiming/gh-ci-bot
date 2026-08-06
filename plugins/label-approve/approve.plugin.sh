#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

# Prow-style: `/approve cancel` revokes the caller's approval.
if [[ "${1:-}" == "cancel" ]]; then
    approve-status.sh unapprove "${LOGIN}"
    exit $?
fi

# The PR author may /approve explicitly; areas they own are already
# approved by default (implicit self-approval).
approve-status.sh approve "${LOGIN}"
