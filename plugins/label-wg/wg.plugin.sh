#!/usr/bin/env bash

IFS=","

label="${*/#/wg\/}"

add-labels.sh "${label}"
