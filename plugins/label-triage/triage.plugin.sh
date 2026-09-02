#!/usr/bin/env bash

IFS=","

label="${*/#/triage\/}"

add-labels.sh "${label}"
