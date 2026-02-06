#!/usr/bin/env bash

IFS=","

label="${*}"

if [[ -z "${label}" ]]; then
  echo "[FAIL] Missing required argument: label name."
  exit 1
fi

echo "Remove label ${label//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-label "${label}" ||
  echo "[FAIL] Failed to remove label \`${label}\`. The label may not be currently applied."
