#!/usr/bin/env bash

# Check if a PR has both "lgtm" and "approved" labels, and trigger auto-merge if so.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

has_lgtm=false
has_approved=false

for label in ${labels}; do
    if [[ "${label}" == "lgtm" ]]; then
        has_lgtm=true
    fi
    if [[ "${label}" == "approved" ]]; then
        has_approved=true
    fi
done

if [[ "${has_lgtm}" == "true" && "${has_approved}" == "true" ]]; then
    echo "PR has both 'lgtm' and 'approved' labels. Auto-merging."
    pr-merge.sh
fi
