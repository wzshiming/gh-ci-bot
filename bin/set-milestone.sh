#!/usr/bin/env bash

milestone="$1"

echo "Setting milestone to ${milestone}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --milestone "${milestone}" ||
  echo "[FAIL] Failed set milestone ${milestone}"
