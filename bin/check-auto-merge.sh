#!/usr/bin/env bash

# Check if a PR has both "lgtm" and "approved" labels and every changed
# area is approved, and trigger auto-merge if so. Runs once at the end of
# every PR event (entrypoint.sh sync_auto_merge), so the merge happens no
# matter which command, sync or UI action removed the last blocker.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

has_lgtm=false
has_approved=false

while read -r label; do
    if [[ -z "${label}" ]]; then
        continue
    fi
    if [[ "${label}" == "lgtm" ]]; then
        has_lgtm=true
    fi
    if [[ "${label}" == "approved" ]]; then
        has_approved=true
    fi
    if [[ "${label}" == do-not-merge/* ]]; then
        echo "PR has the '${label}' label. Skipping auto-merge."
        return 0 2>/dev/null || exit 0
    fi
done <<<"${labels}"

if [[ "${has_lgtm}" == "true" && "${has_approved}" == "true" ]]; then
    # The per-area gate of approve-status.sh needs OWNERS_AREA_APPROVERS;
    # load the OWNERS chain unless the caller already did. Only PRs that
    # really carry lgtm + approved and no blocker pay for the extra calls.
    if [[ -z "${OWNERS_AREA_APPROVERS+x}" ]]; then
        source "$(dirname "${BASH_SOURCE}")/owners.sh"
        load_owners_for_pr
    fi
    if ! approve-status.sh check; then
        echo "PR has both 'lgtm' and 'approved' labels, but not every area is approved. Reconciling."
        approve-status.sh sync
        return 0 2>/dev/null || exit 0
    fi
    echo "PR has both 'lgtm' and 'approved' labels and all areas are approved. Auto-merging."
    pr-merge.sh
fi
