#!/usr/bin/env bash

# Resolve the login the bot acts as, used to find its own comments.
# GitHub App installation tokens (like ones from
# actions/create-github-app-token) cannot call /user, and the app's login
# cannot be derived from the token, so BOT_LOGIN lets the workflow provide
# it explicitly (e.g. "<app-slug>[bot]").

if [[ -n "${BOT_LOGIN:-}" ]]; then
  echo "${BOT_LOGIN}"
  exit 0
fi

BOT_LOGIN=$(gh api /user | jq -r '.login')

# Empty covers a failed gh call, whose empty stdout makes jq print nothing.
if [[ -z "${BOT_LOGIN}" || "${BOT_LOGIN}" == "null" ]]; then
  BOT_LOGIN="github-actions[bot]"
  echo "bot-login: /user is not available for this token, assuming ${BOT_LOGIN}; set BOT_LOGIN if the bot acts as a GitHub App" >&2
fi

echo "${BOT_LOGIN}"
