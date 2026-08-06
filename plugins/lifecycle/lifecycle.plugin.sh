#!/usr/bin/env bash

# Applies a 'lifecycle/<state>' label, mirroring prow's lifecycle plugin.
# The lifecycle labels are mutually exclusive: applying one removes the others.

STATE="${1:-}"

case "${STATE}" in
stale | rotten | frozen) ;;
*)
    echo "[FAIL] Invalid lifecycle state \`${STATE}\`. Available states are: \`stale\`, \`rotten\`, \`frozen\`."
    exit 1
    ;;
esac

labels="$(gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

for other in stale rotten frozen; do
    if [[ "${other}" != "${STATE}" ]] && grep -qxF "lifecycle/${other}" <<<"${labels}"; then
        remove-labels.sh "lifecycle/${other}"
    fi
done

if ! grep -qxF "lifecycle/${STATE}" <<<"${labels}"; then
    add-labels.sh "lifecycle/${STATE}"
fi
