#!/usr/bin/env bash

command.sh 2>&1 | tee ./ci-bot.log

# The placeholder keeps sed from erroring out on an empty pattern when
# GH_TOKEN is unset, which would drop the reply entirely.
LOG=$(cat ./ci-bot.log | grep -e "^\[FAIL\] " | sed -e "s/^\[FAIL\] //g" | sed "s#${GH_TOKEN:-__no_token__}#***#g")

function reply() {
    echo "@${LOGIN}"
    echo
    echo "**I encountered an error while processing your command:**"
    echo
    while IFS= read -r line; do
        echo "> :x: ${line}"
    done <<< "${LOG}"
    echo
    echo "${DETAILS:-}"
}

if [[ "${LOG}" != "" ]]; then
    comment.sh "$(reply)"
fi
