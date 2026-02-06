#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

if [[ "${LOGIN}" == "${AUTHOR}" ]]; then
    echo "[FAIL] you cannot approve your own PR."
    exit 1
fi

add-labels.sh approved

check-auto-merge.sh
