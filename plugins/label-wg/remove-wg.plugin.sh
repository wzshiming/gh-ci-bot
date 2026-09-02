#!/usr/bin/env bash

IFS=","

label="${*/#/wg\/}"

remove-labels.sh "${label}"
