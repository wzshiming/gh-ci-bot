#!/usr/bin/env bash

# Sync the cherry-pick approval labels on a PR, mirroring prow's
# cherrypickunapproved plugin: a PR whose base branch matches the
# RELEASE_BRANCHES regular expression carries
# do-not-merge/cherry-pick-not-approved until it has cherry-pick-approved
# (applied by /cherry-pick-approved); both labels are dropped when the
# base is not a release branch. Labels only: this script never posts
# comments.
#
# Opt-in: does nothing unless the RELEASE_BRANCHES environment variable
# is set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${RELEASE_BRANCHES:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

APPROVED_LABEL="cherry-pick-approved"
UNAPPROVED_LABEL="do-not-merge/cherry-pick-not-approved"

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName,labels)"; then
    # Never mutate labels from missing PR data.
    echo "Failed to get the pull request, skipping the cherry-pick approval sync."
    return 0 2>/dev/null || exit 0
fi

base="$(jq -r '.baseRefName' <<<"${info}")"
labels="$(jq -r '.labels[].name' <<<"${info}")"

# Unquoted so RELEASE_BRANCHES is matched as a regular expression.
[[ "${base}" =~ ${RELEASE_BRANCHES} ]]
matched=$?
if [[ "${matched}" -eq 2 ]]; then
    echo "Invalid RELEASE_BRANCHES regular expression, skipping the cherry-pick approval sync."
    return 0 2>/dev/null || exit 0
fi

if [[ "${matched}" -eq 0 ]]; then
    if grep -qxF "${APPROVED_LABEL}" <<<"${labels}"; then
        if grep -qxF "${UNAPPROVED_LABEL}" <<<"${labels}"; then
            remove-labels.sh "${UNAPPROVED_LABEL}"
        fi
    elif ! grep -qxF "${UNAPPROVED_LABEL}" <<<"${labels}"; then
        add-labels.sh "${UNAPPROVED_LABEL}"
    fi
else
    # Prow prunes both labels once the base moves off a release branch.
    for label in "${APPROVED_LABEL}" "${UNAPPROVED_LABEL}"; do
        if grep -qxF "${label}" <<<"${labels}"; then
            remove-labels.sh "${label}"
        fi
    done
fi
