#!/usr/bin/env bash

IFS=","

label="${*/#/kind\/}"

add-labels.sh "${label}"
