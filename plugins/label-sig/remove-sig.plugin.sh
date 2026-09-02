#!/usr/bin/env bash

IFS=","

label="${*/#/sig\/}"

remove-labels.sh "${label}"
