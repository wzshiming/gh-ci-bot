#!/usr/bin/env bash

IFS=","

label="${*/#/kind\/}"

remove-labels.sh "${label}"
