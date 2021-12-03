#!/usr/bin/env bash

IFS=","

login="${*}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] No login provided"
  exit 1
fi

echo "Add assignee ${login//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-assignee "${login//\@/}"
