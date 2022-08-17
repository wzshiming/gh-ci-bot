#!/usr/bin/env bash

"$@" 2>&1 | tee ./shell-output.log

cmd="$@"
function reply() {
    echo "\`> ${cmd}\`"
    echo '<details>'
    echo
    echo '``` console'
    cat shell-output.log | sed "s#${GH_TOKEN}#***#g"
    echo
    echo '```'
    echo '</details>'
}

comment.sh "$(reply)"
