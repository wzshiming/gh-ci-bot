#!/usr/bin/env bash

IFS=","

login="${*}"
login="${login//\@/}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] No login provided"
  exit 1
fi

echo "Remove assignee ${login} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"

# gh issue edit --add-assignee Users whose names contain uppercase characters are prompted with user not found
# https://github.com/wzshiming/gh-ci-bot/issues/26
# for assignee in ${login}; do
#   gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-assignee "${assignee}" ||
#     echo "[FAIL] Failed remove assignee ${assignee}"
# done

for assignee in ${login}; do
  curl \
    -X DELETE \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GH_TOKEN}" \
    "https://api.github.com/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/assignees" \
    -d "{\"assignees\":[\"${assignee}\"]}" ||
    echo "[FAIL] Failed remove assignee ${assignee}"
done
