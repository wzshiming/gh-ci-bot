#!/usr/bin/env bash

IFS=","

label="${*}"

if [[ -z "${label}" ]]; then
  echo "[FAIL] No label provided"
  exit 1
fi

echo "Remove label ${label//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-label "${label}" ||
  echo "[FAIL] Failed remove label ${label}"
