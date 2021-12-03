#!/usr/bin/env bash

if [[ "${GREETING}" != "" ]] ; then
    comment.sh "${GREETING:-}
${DETAILS:-}"
fi
