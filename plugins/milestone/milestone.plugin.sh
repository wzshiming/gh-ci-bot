#!/usr/bin/env bash

milestone="${1:-}"

if [[ -z "${milestone}" ]]; then
  echo "[FAIL] Missing required argument: milestone name. Usage: \`/milestone <name>\`"
  exit 1
fi

set-milestone.sh "${milestone}"
