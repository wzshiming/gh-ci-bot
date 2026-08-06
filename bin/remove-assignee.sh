#!/usr/bin/env bash

IFS=","

login="${*}"
login="${login//\@/}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] Missing required argument: username. Usage: \`/unassign @username\`"
  exit 1
fi

echo "Remove assignee ${login} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"

# The issue with usernames containing uppercase characters was fixed upstream
# in gh v2.16.0 (https://github.com/cli/cli/issues/6167)
for assignee in ${login}; do
  gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-assignee "${assignee}" ||
    echo "[FAIL] Failed to remove assignee ${assignee}. Please check that the username is correct."
done
