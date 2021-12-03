#!/usr/bin/env bash

IFS=","

label="${*/#/kind\/}"

add-label.sh "${label}"
