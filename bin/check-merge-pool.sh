#!/usr/bin/env bash

# Reconcile the merge pool, mirroring tide's sync loop: every open PR
# carrying both the "lgtm" and "approved" labels is a candidate. The
# candidates are evaluated oldest first, one at a time, through the same
# validation and merge path as the per-event auto-merge check
# (check-auto-merge.sh), so merges are serialized: the first merge makes
# the remaining candidates stale, and they are updated and retested
# against the new base before a later sync merges them.
#
# Runs on the scheduled sync event (entrypoint.sh, TYPE "schedule"). The
# schedule fills the gap the per-PR events leave: neither a finished
# check nor another PR's merge triggers a bot event on a pool PR, so
# without the periodic reconcile a PR that turned green or stale in the
# background would sit in the pool until someone touched it.

if ! pool="$(gh pr -R "${GH_REPOSITORY}" list --state open --search "label:lgtm label:approved sort:created-asc" --json number --jq '.[].number')"; then
    echo "Failed to list the merge pool."
    exit 1
fi

if [[ -z "${pool}" ]]; then
    echo "The merge pool is empty."
    exit 0
fi

while read -r number; do
    if [[ -z "${number}" ]]; then
        continue
    fi
    echo "Evaluating merge pool PR #${number}"
    # Each candidate changes different areas, so its approval gate must
    # load its own OWNERS chain: clear any inherited owners state.
    env -u OWNERS_AREAS -u OWNERS_AREA_APPROVERS -u OWNERS_LABELS \
        ISSUE_NUMBER="${number}" check-auto-merge.sh ||
        echo "Failed to evaluate merge pool PR #${number}"
done <<<"${pool}"
