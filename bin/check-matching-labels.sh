#!/usr/bin/env bash

# Sync "needs-*" labels on an issue or PR, mirroring prow's
# require-matching-label plugin: when no label matching a configured regex
# is present, the configured missing label (e.g. needs-kind) is added, and
# the missing label is removed once a matching label is added.
#
# Rules are configured via the ISSUE_REQUIRE_MATCHING_LABELS (issues) and
# PR_REQUIRE_MATCHING_LABELS (PRs) environment variables, selected by
# ISSUE_KIND, falling back to REQUIRE_MATCHING_LABELS for both when the
# scoped variable is unset. One rule per line in the format:
#   <missing-label> <regexp>
# Defaults to requiring a kind/* label via the needs-kind label.

if [[ "${ISSUE_KIND}" == "pr" ]]; then
    RULES="${PR_REQUIRE_MATCHING_LABELS-${REQUIRE_MATCHING_LABELS-needs-kind ^kind/}}"
else
    RULES="${ISSUE_REQUIRE_MATCHING_LABELS-${REQUIRE_MATCHING_LABELS-needs-kind ^kind/}}"
fi

if [[ -z "${RULES}" ]]; then
    return 0 2>/dev/null || exit 0
fi

labels="$(gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

while read -r missing_label regexp _; do
    if [[ -z "${missing_label}" || -z "${regexp}" ]]; then
        continue
    fi

    has_missing=false
    has_matching=false
    while read -r label; do
        if [[ -z "${label}" ]]; then
            continue
        fi
        if [[ "${label}" == "${missing_label}" ]]; then
            has_missing=true
        elif grep -qE "${regexp}" <<<"${label}"; then
            has_matching=true
        fi
    done <<<"${labels}"

    if [[ "${has_matching}" == "true" ]]; then
        if [[ "${has_missing}" == "true" ]]; then
            echo "Found a label matching \`${regexp}\`, removing ${missing_label}"
            remove-labels.sh "${missing_label}"
        fi
    elif [[ "${has_missing}" != "true" ]]; then
        echo "No label matching \`${regexp}\`, adding ${missing_label}"
        add-labels.sh "${missing_label}"
    fi
done <<<"${RULES}"
