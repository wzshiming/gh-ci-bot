#!/usr/bin/env bash

IFS=","

label="${*/#/committee\/}"

remove-labels.sh "${label}"
