#!/usr/bin/env bash

IFS=","

label="${*/#/sig\/}"

add-labels.sh "${label}"
