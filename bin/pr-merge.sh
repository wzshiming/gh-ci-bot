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
    echo "[FAIL] Invalid merge method: \`${action}\`. Supported methods are: \`rebase\`, \`squash\`, or omit for default merge."
    exit 1
  fi
fi

echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} merge by ${LOGIN}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" merge "${ISSUE_NUMBER}" --auto "${args}" ||
  echo "[FAIL] Failed to merge the PR. Please ensure all required checks have passed and there are no conflicts."
