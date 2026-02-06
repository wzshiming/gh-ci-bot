#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

IFS=','

login="${*:-${LOGIN}}"

remove-reviewer.sh "${login}"
