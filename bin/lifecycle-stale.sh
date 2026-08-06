#!/usr/bin/env bash

# lifecycle-stale.sh - Ages open issues and PRs based on inactivity,
# mirroring the Kubernetes stale bot periodics:
# - After DAYS_UNTIL_STALE days without activity, mark 'lifecycle/stale'.
# - After DAYS_UNTIL_ROTTEN more days, mark 'lifecycle/rotten'.
# - After DAYS_UNTIL_CLOSE more days, close the issue or PR.
# Items labeled 'lifecycle/frozen' are never aged.
#
# Intended to be run from a scheduled workflow with TYPE=periodic.

DAYS_UNTIL_STALE="${DAYS_UNTIL_STALE:-90}"
DAYS_UNTIL_ROTTEN="${DAYS_UNTIL_ROTTEN:-30}"
DAYS_UNTIL_CLOSE="${DAYS_UNTIL_CLOSE:-30}"

# cutoff_date prints the UTC date the given number of days ago,
# in the format accepted by GitHub search qualifiers.
function cutoff_date() {
    date -u -d "${1} days ago" +%Y-%m-%dT%H:%M:%SZ
}

# search_items prints "<number> <issue|pr>" for every open item in the
# repository matching the given extra search qualifiers.
function search_items() {
    gh api -X GET search/issues --paginate \
        -f q="repo:${GH_REPOSITORY} is:open -label:lifecycle/frozen ${*}" \
        -F per_page=100 \
        --jq '.items[] | "\(.number) \(if .pull_request then "pr" else "issue" end)"'
}

# process runs the given action for every item matching the search query.
function process() {
    local action="$1"
    shift
    local number kind
    while read -r number kind; do
        if [[ -z "${number}" ]]; then
            continue
        fi
        ISSUE_NUMBER="${number}" ISSUE_KIND="${kind}" "${action}"
    done <<<"$(search_items "${@}")"
}

function mark_stale() {
    echo "Marking ${GH_REPOSITORY}#${ISSUE_NUMBER} as stale"
    add-labels.sh lifecycle/stale
    comment.sh "Issues go stale after ${DAYS_UNTIL_STALE}d of inactivity.
Mark the issue as fresh with \`/remove-lifecycle stale\`.
Stale issues rot after an additional ${DAYS_UNTIL_ROTTEN}d of inactivity and eventually close.

If this issue is safe to close now please do so with \`/close\`."
}

function mark_rotten() {
    echo "Marking ${GH_REPOSITORY}#${ISSUE_NUMBER} as rotten"
    remove-labels.sh lifecycle/stale
    add-labels.sh lifecycle/rotten
    comment.sh "Stale issues rot after ${DAYS_UNTIL_ROTTEN}d of inactivity.
Mark the issue as fresh with \`/remove-lifecycle rotten\`.
Rotten issues close after an additional ${DAYS_UNTIL_CLOSE}d of inactivity.

If this issue is safe to close now please do so with \`/close\`."
}

function close_rotten() {
    echo "Closing ${GH_REPOSITORY}#${ISSUE_NUMBER}"
    comment.sh "Rotten issues close after ${DAYS_UNTIL_CLOSE}d of inactivity.
Reopen the issue with \`/reopen\`.
Mark the issue as fresh with \`/remove-lifecycle rotten\`."
    gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" close "${ISSUE_NUMBER}"
}

# Close rotten items first so that they are not re-processed below.
process close_rotten "label:lifecycle/rotten updated:<$(cutoff_date "${DAYS_UNTIL_CLOSE}")"

# Rot stale items.
process mark_rotten "label:lifecycle/stale -label:lifecycle/rotten updated:<$(cutoff_date "${DAYS_UNTIL_ROTTEN}")"

# Mark inactive items as stale.
process mark_stale "-label:lifecycle/stale -label:lifecycle/rotten updated:<$(cutoff_date "${DAYS_UNTIL_STALE}")"
