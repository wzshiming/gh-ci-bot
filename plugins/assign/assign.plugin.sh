#!/usr/bin/env bash

IFS=','

login="${*:-${LOGIN}}"

add-assignee.sh "${login}"
