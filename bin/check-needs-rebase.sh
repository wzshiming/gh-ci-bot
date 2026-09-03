#!/usr/bin/env bash

# Sync the needs-rebase label on a PR, mirroring prow's needs-rebase
# external plugin: a PR that has merge conflicts with the base branch
# gets the needs-rebase label, and once the conflicts are resolved the
# label is removed automatically. Labels only: this script never posts
# comments. Complements the /rebase command.
#
# Opt-in: does nothing unless the NEEDS_REBASE environment variable is
# set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${NEEDS_REBASE:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

NEEDS_REBASE_LABEL="needs-rebase"

# GitHub computes mergeability asynchronously, so shortly after a push it
# reports UNKNOWN for a while; poll a few times to let it settle.
state=""
mergeable=""
labels=""
for try in 1 2 3 4 5; do
    if [[ "${try}" -ne 1 ]]; then
        sleep 5
    fi
    if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json mergeable,state,labels)"; then
        # Never mutate labels from missing PR data.
        echo "Failed to get the pull request, skipping the needs-rebase sync."
        return 0 2>/dev/null || exit 0
    fi
    state="$(echo "${info}" | jq -r '.state')"
    mergeable="$(echo "${info}" | jq -r '.mergeable')"
    labels="$(echo "${info}" | jq -r '.labels[].name')"
    if [[ "${state}" != "OPEN" || "${mergeable}" != "UNKNOWN" ]]; then
        break
    fi
done

# Closed and merged PRs never need a rebase.
if [[ "${state}" != "OPEN" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "${mergeable}" == "CONFLICTING" ]]; then
    if ! grep -qxF "${NEEDS_REBASE_LABEL}" <<<"${labels}"; then
        add-labels.sh "${NEEDS_REBASE_LABEL}"
    fi
elif [[ "${mergeable}" == "MERGEABLE" ]]; then
    if grep -qxF "${NEEDS_REBASE_LABEL}" <<<"${labels}"; then
        remove-labels.sh "${NEEDS_REBASE_LABEL}"
    fi
else
    echo "Mergeability of the pull request is not known yet, skipping the needs-rebase sync."
fi
