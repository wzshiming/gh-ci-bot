#!/usr/bin/env bash

command.sh 2>&1 | tee ./ci-bot.log

LOG=$(cat ./ci-bot.log | grep -e "^\[FAIL\] " | sed -e "s/^\[FAIL\] //g")

if [[ "${LOG}" != "" ]]; then
    comment.sh "
@${LOGIN}

\`\`\` console
${LOG}
\`\`\`

${DETAILS:-}
"

fi
