#!/usr/bin/env bash

state="${1}"

case "${state}" in
stale | rotten | frozen)
    ;;
*)
    echo "[FAIL] Invalid lifecycle state \`${state}\`. Available states are: \`stale\`, \`rotten\`, \`frozen\`."
    exit 1
    ;;
esac

remove-labels.sh "lifecycle/${state}"
