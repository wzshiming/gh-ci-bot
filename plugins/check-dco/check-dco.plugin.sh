#!/usr/bin/env bash

# /check-dco - re-run the DCO signoff check of the PR, syncing the
# dco-signoff labels, mirroring prow's dco plugin.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

if [[ -z "${DCO_REQUIRED:-}" ]]; then
    echo "[FAIL] The DCO check is not enabled for this repository. Set the \`DCO_REQUIRED\` environment variable to enable it."
    exit 1
fi

check-dco.sh
