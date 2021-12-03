#!/usr/bin/env bash

IFS=","

label="${*/#/kind\/}"

remove-label.sh "${label}"
