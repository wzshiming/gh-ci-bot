#!/usr/bin/env bash

IFS=","

label="${*/#/area\/}"

remove-labels.sh "${label}"
