#!/usr/bin/env bash

# Explains why a push or merge touching .github/workflows/ was refused: the
# default GITHUB_TOKEN can never be granted the `workflows` permission.
# Reads the changed paths from stdin and prints one [FAIL] line; exits 1
# without output when this is not the cause, so callers just fall through.

mapfile -t files < <(grep '^\.github/workflows/')

if [[ "${#files[@]}" -eq 0 || "$(bot-login.sh)" != "github-actions[bot]" ]]; then
  exit 1
fi

list="$(printf '`%s`, ' "${files[@]}")"
echo "[FAIL] This change touches ${list}which the default \`GITHUB_TOKEN\` cannot merge or push because it cannot be granted the \`workflows\` permission. Run the bot with a PAT that has the \`workflow\` scope or a GitHub App token with \`workflows: write\` as \`GH_TOKEN\`, or do it manually."
