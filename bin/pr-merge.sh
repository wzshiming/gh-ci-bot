#!/usr/bin/env bash

IFS=","

action="${1:-}"

args="--merge"

if [[ "${action}" != "" ]]; then
  if [[ "${action}" == "rebase" ]]; then
    args="--rebase"
  elif [[ "${action}" == "squash" ]]; then
    args="--squash"
  else
    echo "[FAIL] Invalid action: ${action}"
    exit 1
  fi
fi

echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} merge by ${LOGIN}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" merge "${ISSUE_NUMBER}" --auto "${args}"
