#!/usr/bin/env bash

# Removes a 'lifecycle/<state>' label, mirroring prow's lifecycle plugin.

STATE="${1:-}"

case "${STATE}" in
stale | rotten | frozen) ;;
*)
    echo "[FAIL] Invalid lifecycle state \`${STATE}\`. Available states are: \`stale\`, \`rotten\`, \`frozen\`."
    exit 1
    ;;
esac

remove-labels.sh "lifecycle/${STATE}"
