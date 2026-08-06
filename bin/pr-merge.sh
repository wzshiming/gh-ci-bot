#!/usr/bin/env bash

IFS=","

action="${1:-}"

default_merge_method="${DEFAULT_MERGE_METHOD:-merge}"
method="${action:-${default_merge_method}}"

args=""

if [[ "${method}" == "merge" || "${method}" == "" ]]; then
  args="--merge"
elif [[ "${method}" == "rebase" ]]; then
  args="--rebase"
elif [[ "${method}" == "squash" ]]; then
  args="--squash"
else
  echo "[FAIL] Invalid merge method: \`${method}\`. Supported methods are: \`merge\`, \`rebase\`, or \`squash\`. Use \`DEFAULT_MERGE_METHOD\` to set the default."
  exit 1
fi

blocking_labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '[.labels[].name | select(startswith("do-not-merge/"))] | join("`, `")')"
if [[ -n "${blocking_labels}" ]]; then
  echo "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`${blocking_labels}\`."
  exit 1
fi

echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} merge by ${LOGIN}"
gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" merge "${ISSUE_NUMBER}" --auto "${args}" ||
  echo "[FAIL] Failed to merge the PR. Please ensure all required checks have passed and there are no conflicts."
