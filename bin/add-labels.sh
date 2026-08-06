#!/usr/bin/env bash

IFS=","

label="${*}"

if [[ -z "${label}" ]]; then
  echo "[FAIL] Missing required argument: label name."
  exit 1
fi

# Make sure the labels exist so adding them cannot fail.
ensure-labels.sh "${@}"

echo "Add label ${label//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-label "${label}" ||
  echo "[FAIL] Failed to add label \`${label}\`."
