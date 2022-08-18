#!/usr/bin/env bash

command.sh 2>&1 | tee ./ci-bot.log

LOG=$(cat ./ci-bot.log | grep -e "^\[FAIL\] " | sed -e "s/^\[FAIL\] //g" | sed "s#${GH_TOKEN}#***#g")

function reply() {
    echo "@${LOGIN}"
    echo
    echo '``` console'
    echo
    echo "${LOG}"
    echo
    echo '```'
    echo
    echo "${DETAILS:-}"
}

if [[ "${LOG}" != "" ]]; then
    comment.sh "$(reply)"
fi
