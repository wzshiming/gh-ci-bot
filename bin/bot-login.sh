#!/usr/bin/env bash

BOT_LOGIN=$(gh api /user | jq -r '.login')

# Empty covers a failed gh call, whose empty stdout makes jq print nothing.
if [[ -z "${BOT_LOGIN}" || "${BOT_LOGIN}" == "null" ]]; then
  BOT_LOGIN="github-actions[bot]"
fi

echo "${BOT_LOGIN}"
