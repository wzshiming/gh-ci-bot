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

# Lifecycle labels are mutually exclusive, remove the others first.
for other in stale rotten frozen; do
    if [[ "${other}" != "${state}" ]]; then
        gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --remove-label "lifecycle/${other}" >/dev/null 2>&1 || true
    fi
done

add-labels.sh "lifecycle/${state}"
