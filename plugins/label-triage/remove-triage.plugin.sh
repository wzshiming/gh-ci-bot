#!/usr/bin/env bash

IFS=","

label="${*/#/triage\/}"

remove-labels.sh "${label}"
