#!/usr/bin/env bash

BOT_LOGIN=$(bot-login.sh)
gh api "/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/comments" |\
    jq -r ".[] | select(.user.login == \"${BOT_LOGIN}\") | .id" |\
    xargs -I {} gh api "/repos/${GH_REPOSITORY}/issues/comments/{}" --silent -X DELETE
