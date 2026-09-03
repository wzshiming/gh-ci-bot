#!/usr/bin/env bash

# Prints the login the bot's comments are authored by. GITHUB_TOKEN and PATs
# resolve it via /user; GitHub App installation tokens cannot (HTTP 403), so
# App users must set BOT_LOGIN to the App's login ("<app-slug>[bot]").

if [[ -n "${BOT_LOGIN:-}" ]]; then
  echo "${BOT_LOGIN}"
  exit 0
fi

BOT_LOGIN=$(gh api /user | jq -r '.login')

# Empty covers a failed gh call, whose empty stdout makes jq print nothing.
if [[ -z "${BOT_LOGIN}" || "${BOT_LOGIN}" == "null" ]]; then
  echo "Could not resolve the bot login via /user, assuming github-actions[bot]; set BOT_LOGIN if the bot comments as another user (e.g. a GitHub App)." >&2
  BOT_LOGIN="github-actions[bot]"
fi

echo "${BOT_LOGIN}"
