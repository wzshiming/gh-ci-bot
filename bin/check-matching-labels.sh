#!/usr/bin/env bash

# Sync "needs-*" labels on an issue or PR, mirroring prow's
# require-matching-label plugin: when no label matches the configured
# regular expression, the configured missing label (e.g. needs-kind) is
# added together with an explanatory comment, and the missing label is
# removed once a matching label is present.
#
# Rules are read from the REQUIRE_MATCHING_LABELS environment variable,
# one rule per line, with fields separated by ";":
#
#   <missing-label>;<regexp>[;<target>[;<comment>]]
#
#   missing-label  label added while no label matches the regexp
#   regexp         extended regular expression matched against label names
#   target         "issue", "pr" or "both" (default "both")
#   comment        explanatory comment posted when the label is added
#                  (a default message is used when omitted)
#
# Example:
#
#   REQUIRE_MATCHING_LABELS: |-
#     needs-kind;^kind/;both;Please add a kind/ label with `/kind <kind>`.

if [[ -z "${REQUIRE_MATCHING_LABELS:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

current_labels="$(gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

while IFS=';' read -r missing_label regexp target comment; do
    if [[ -z "${missing_label}" || -z "${regexp}" ]]; then
        continue
    fi

    target="${target:-both}"
    if [[ "${target}" != "both" && "${target}" != "${ISSUE_KIND}" ]]; then
        continue
    fi

    if [[ -z "${comment}" ]]; then
        comment="@${AUTHOR:-${LOGIN}} There is not a label matching \`${regexp}\` on this ${ISSUE_KIND}. Please add one so it can be triaged, then the \`${missing_label}\` label will be removed."
    fi

    has_missing_label=false
    if grep -qxF "${missing_label}" <<<"${current_labels}"; then
        has_missing_label=true
    fi

    has_matching_label=false
    if grep -vxF "${missing_label}" <<<"${current_labels}" | grep -qE "${regexp}"; then
        has_matching_label=true
    fi

    if [[ "${has_matching_label}" == "true" && "${has_missing_label}" == "true" ]]; then
        remove-labels.sh "${missing_label}"
    elif [[ "${has_matching_label}" != "true" && "${has_missing_label}" != "true" ]]; then
        add-labels.sh "${missing_label}"
        comment.sh "${comment}"
    fi
done <<<"${REQUIRE_MATCHING_LABELS}"
