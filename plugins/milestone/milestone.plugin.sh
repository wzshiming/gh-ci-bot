#!/usr/bin/env bash

milestone="${1:-}"

if [[ -z "${milestone}" ]]; then
  echo "[FAIL] Missing required argument: milestone name. Usage: \`/milestone <name>\`"
  exit 1
fi

# Prow-style keyword, so a milestone literally named "clear" cannot be set.
if [[ "${milestone}" == "clear" ]]; then
  set-milestone.sh ""
  exit $?
fi

set-milestone.sh "${milestone}"
