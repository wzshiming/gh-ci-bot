#!/usr/bin/env bash

BOT_LOGIN=$(gh api /user | jq -r '.login')

if [[ "${BOT_LOGIN}" == "null" ]]; then
  BOT_LOGIN="github-actions[bot]"
fi

echo "${BOT_LOGIN}"
