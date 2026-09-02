#!/usr/bin/env bash

IFS=","

label="${*/#/priority\/}"

add-labels.sh "${label}"
