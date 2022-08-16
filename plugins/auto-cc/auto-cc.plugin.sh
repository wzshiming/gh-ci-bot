#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This plugin only works with pull requests."
    exit 1
fi

login=$(echo "${REVIEWERS}" | shuf | head -n 2 | tr '\n' ',' | sed 's/,$//')
if [[ -z "${login}" ]]; then
    echo "[FAIL] No reviewers specified. Skipping auto-cc."
    exit 1
fi

echo "Auto-ccing ${login}."

add-reviewer.sh "${login}"
