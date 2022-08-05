#!/usr/bin/env bash

IFS=","

login="${*}"
login="${login//\@/}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] No login provided"
  exit 1
fi

echo "Remove assignee ${login} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"

for assignee in ${login}; do
  gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-assignee "${assignee}" ||
    echo "[FAIL] Failed remove assignee ${assignee}"
done
