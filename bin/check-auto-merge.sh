#!/usr/bin/env bash

# Check if a PR has both "lgtm" and "approved" labels and every changed
# area is approved, and trigger auto-merge if so. Runs once at the end of
# every PR event (entrypoint.sh sync_auto_merge) and once per candidate
# on every scheduled merge-pool sync (check-merge-pool.sh), so the merge
# happens no matter which command, sync or UI action removed the last
# blocker.
#
# Before merging, the PR state is re-validated the way tide reconciles
# its pool: the merge only happens when the PR has no conflicts, its head
# contains the latest base commit (so the checks ran against the current
# base) and every check on the head is green. A PR that is behind its
# base is never merged; with AUTO_MERGE_UPDATE_BRANCH set, the bot merges
# the base into it so the checks re-run against the latest base and a
# later sync merges it. Only merging fresh PRs serializes merges: each
# merge makes the rest of the pool stale, so the others are retested
# against the new base before they can merge, avoiding semantic conflicts
# between PRs that were green in isolation.

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

if [[ "${has_lgtm}" != "true" || "${has_approved}" != "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

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
echo "PR has both 'lgtm' and 'approved' labels and all areas are approved. Validating merge readiness."

# Fail closed: never merge without having seen the current merge state.
if ! merge_state="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName,headRefOid,mergeable,statusCheckRollup)"; then
    echo "Failed to fetch the PR merge state. Skipping auto-merge."
    return 0 2>/dev/null || exit 0
fi

mergeable="$(jq -r '.mergeable' <<<"${merge_state}")"
if [[ "${mergeable}" == "CONFLICTING" ]]; then
    echo "PR has conflicts with the base branch. Skipping auto-merge."
    return 0 2>/dev/null || exit 0
fi
if [[ "${mergeable}" != "MERGEABLE" ]]; then
    echo "PR mergeability is still being computed by GitHub. Skipping auto-merge."
    return 0 2>/dev/null || exit 0
fi

# Base freshness: only merge a head that contains the latest base commit,
# so the green checks really validated the result of this merge.
base_ref="$(jq -r '.baseRefName' <<<"${merge_state}")"
head_oid="$(jq -r '.headRefOid' <<<"${merge_state}")"
if ! behind_by="$(gh api "/repos/${GH_REPOSITORY}/compare/${base_ref}...${head_oid}?per_page=1" --jq '.behind_by')"; then
    echo "Failed to compare the PR with its base branch. Skipping auto-merge."
    return 0 2>/dev/null || exit 0
fi
if [[ "${behind_by}" != "0" ]]; then
    echo "PR is behind the base branch by ${behind_by} commit(s), so its checks did not run against the latest base. Skipping auto-merge."
    if [[ -n "${AUTO_MERGE_UPDATE_BRANCH:-}" ]]; then
        echo "Updating the branch to retest against the latest base."
        gh pr -R "${GH_REPOSITORY}" update-branch "${ISSUE_NUMBER}" ||
            echo "Failed to update the branch."
    fi
    return 0 2>/dev/null || exit 0
fi

# Checks green: every check run and commit status on the head commit must
# have finished successfully. The bot's own workflow is excluded: a
# pull_request_target run of the bot is itself a check on the head, so
# counting it would deadlock every run on its own in-progress check.
checks="$(jq -r --arg self "${GITHUB_WORKFLOW:-}" '
    [.statusCheckRollup[]?
        | select(($self == "") or ((.workflowName // "") != $self))
        | if .__typename == "StatusContext" then
            if .state == "SUCCESS" then "passing"
            elif .state == "PENDING" or .state == "EXPECTED" then "pending"
            else "failing"
            end
        elif .status != "COMPLETED" then "pending"
        elif .conclusion == "SUCCESS" or .conclusion == "NEUTRAL" or .conclusion == "SKIPPED" then "passing"
        else "failing"
        end]
    | if any(.[]; . == "failing") then "failing"
    elif any(.[]; . == "pending") then "pending"
    else "passing"
    end' <<<"${merge_state}")"
if [[ "${checks}" == "failing" ]]; then
    echo "Some checks on the PR are failing. Skipping auto-merge."
    return 0 2>/dev/null || exit 0
fi
if [[ "${checks}" != "passing" ]]; then
    echo "Some checks on the PR are still pending. Skipping auto-merge until they finish."
    return 0 2>/dev/null || exit 0
fi

echo "PR is up to date with the base branch and every check is green. Auto-merging."
pr-merge.sh
