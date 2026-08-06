#!/usr/bin/env bash

IFS=","

label="${*}"

if [[ -z "${label}" ]]; then
  echo "[FAIL] Missing required argument: label name."
  exit 1
fi

echo "Add label ${label//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
if ! gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-label "${label}"; then
  # Adding failed, likely because a label does not exist yet.
  # Create the missing labels and retry.
  ensure-labels.sh "${@}"
  gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-label "${label}" ||
    echo "[FAIL] Failed to add label \`${label}\`."
fi
