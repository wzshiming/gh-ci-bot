#!/usr/bin/env bash

IFS=','

login="${*:-${LOGIN}}"

remove-assignee.sh "${login}"
