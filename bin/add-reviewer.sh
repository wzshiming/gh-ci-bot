#!/usr/bin/env bash

IFS=","

login="${*}"
login="${login//\@/}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] No login provided"
  exit 1
fi

echo "Add reviewer ${login} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"

# gh pr edit --add-reviewer Don't acquire organizational teams if it's not necessary
# see more https://github.com/wzshiming/gh-ci-bot/issues/1 
# gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-reviewer "${login}"

for reviewer in ${login}; do
  curl \
    -X POST \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Authorization: token ${GH_TOKEN}" \
    "https://api.github.com/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/requested_reviewers" \
    -d "{\"reviewers\":[\"${reviewer}\"],\"team_reviewers\":[]}" ||
    echo "[FAIL] Failed requeste review ${reviewer}"
done
