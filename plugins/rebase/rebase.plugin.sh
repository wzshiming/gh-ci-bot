#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

gh api \
    --method PUT \
    -H "Accept: application/vnd.github+json" \
    /repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/update-branch \
    -f update_method=rebase ||
    echo "[FAIL] Failed rebase branch"
