#!/usr/bin/env bash

IFS=","

label="${*/#/committee\/}"

add-labels.sh "${label}"
