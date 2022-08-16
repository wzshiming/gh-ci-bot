#!/usr/bin/env bash

milestone="${1:-}"

if [[ -z "${milestone}" ]]; then
  echo "[FAIL] No milestone specified"
  exit 1
fi

set-milestone.sh "${milestone}"
