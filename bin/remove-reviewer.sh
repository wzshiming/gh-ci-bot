#!/usr/bin/env bash

IFS=","

login="${*}"
login="${login//\@/}"

if [[ -z "${login}" ]]; then
  echo "[FAIL] Missing required argument: username. Usage: \`/uncc @username\`"
  exit 1
fi

echo "Remove reviewer ${login} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"

# gh pr edit --remove-reviewer no longer fetches organizational teams when it's not necessary,
# so it works with the GitHub Actions token since gh v2.82.0.
# see more https://github.com/wzshiming/gh-ci-bot/issues/1
# and https://github.com/cli/cli/issues/4844 fixed by https://github.com/cli/cli/pull/11835

for reviewer in ${login}; do
  gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-reviewer "${reviewer}" ||
    echo "[FAIL] Failed to remove reviewer ${reviewer}. Please check that the username is correct."
done
