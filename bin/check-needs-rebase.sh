#!/usr/bin/env bash

# Sync the "needs-rebase" label on a PR, mirroring prow's needs-rebase
# external plugin: the label is added with a comment asking the author to
# rebase when the PR has merge conflicts, and removed automatically once
# the conflicts are resolved.
#
# Usage:
#   check-needs-rebase.sh        Sync the PR identified by ISSUE_NUMBER.
#   check-needs-rebase.sh all    Sync every open PR, optionally filtered by
#                                the BASE_BRANCH environment variable.

NEEDS_REBASE_LABEL="needs-rebase"

# sync_needs_rebase syncs the needs-rebase label on the given PR number.
function sync_needs_rebase() {
    local number="$1"
    local info mergeable has_label author

    # GitHub computes mergeability asynchronously, so retry while it
    # reports UNKNOWN, mirroring prow's needs-rebase plugin.
    mergeable="UNKNOWN"
    for _ in $(seq 1 5); do
        info="$(gh pr -R "${GH_REPOSITORY}" view "${number}" --json mergeable,labels,author)"
        mergeable="$(echo "${info}" | jq -r '.mergeable')"
        if [[ "${mergeable}" != "UNKNOWN" ]]; then
            break
        fi
        sleep 5
    done

    if [[ "${mergeable}" == "UNKNOWN" ]]; then
        echo "PR #${number} mergeability is still unknown. Skipping needs-rebase sync."
        return 0
    fi

    has_label="$(echo "${info}" | jq -r --arg l "${NEEDS_REBASE_LABEL}" '[.labels[].name] | contains([$l])')"
    author="$(echo "${info}" | jq -r '.author.login')"

    if [[ "${mergeable}" == "CONFLICTING" && "${has_label}" != "true" ]]; then
        ISSUE_NUMBER="${number}" ISSUE_KIND="pr" add-labels.sh "${NEEDS_REBASE_LABEL}"
        ISSUE_NUMBER="${number}" ISSUE_KIND="pr" comment.sh "@${author}: PR needs rebase.
Adding label \`${NEEDS_REBASE_LABEL}\`.
This PR has merge conflicts with the base branch. Please rebase your branch onto the latest base branch and resolve the conflicts, or comment \`/rebase\` to have me try to update the branch for you.
${DETAILS:-}"
    elif [[ "${mergeable}" == "MERGEABLE" && "${has_label}" == "true" ]]; then
        ISSUE_NUMBER="${number}" ISSUE_KIND="pr" remove-labels.sh "${NEEDS_REBASE_LABEL}"
    fi
}

if [[ "${1:-}" == "all" ]]; then
    args=(--limit 100 --json number)
    if [[ -n "${BASE_BRANCH:-}" ]]; then
        args+=(--base "${BASE_BRANCH}")
    fi
    numbers="$(gh pr -R "${GH_REPOSITORY}" list --state open "${args[@]}" --jq '.[].number')"
    for number in ${numbers}; do
        sync_needs_rebase "${number}"
    done
    return 0 2>/dev/null || exit 0
fi

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

sync_needs_rebase "${ISSUE_NUMBER}"
