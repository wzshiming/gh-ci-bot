#!/usr/bin/env bash

IFS=","

label="${*/#/area\/}"

add-labels.sh "${label}"
