#!/usr/bin/env bash

IFS=","

label="${*/#/priority\/}"

remove-labels.sh "${label}"
