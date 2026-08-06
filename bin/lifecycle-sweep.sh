#!/usr/bin/env bash

# lifecycle-sweep.sh ages open issues and PRs, mirroring the k8s stale bot:
# no activity -> lifecycle/stale -> lifecycle/rotten -> closed.
# Anything labeled lifecycle/frozen is left untouched.

DAYS_UNTIL_STALE="${DAYS_UNTIL_STALE:-90}"
DAYS_UNTIL_ROTTEN="${DAYS_UNTIL_ROTTEN:-30}"
DAYS_UNTIL_CLOSE="${DAYS_UNTIL_CLOSE:-30}"

function date_before() {
    local days="$1"
    date -u -d "${days} days ago" +%Y-%m-%dT%H:%M:%SZ
}

function search_numbers() {
    local query="$1"
    gh api search/issues -X GET --paginate \
        -f q="repo:${GH_REPOSITORY} is:open -label:lifecycle/frozen ${query}" \
        -q '.items[].number'
}

function add_label() {
    local number="$1"
    local label="$2"
    gh api "repos/${GH_REPOSITORY}/issues/${number}/labels" -f "labels[]=${label}" >/dev/null
}

function remove_label() {
    local number="$1"
    local label="${2//\//%2F}"
    gh api -X DELETE "repos/${GH_REPOSITORY}/issues/${number}/labels/${label}" >/dev/null 2>&1 || true
}

function add_comment() {
    local number="$1"
    local body="$2"
    gh api "repos/${GH_REPOSITORY}/issues/${number}/comments" -f "body=${body}" >/dev/null
}

function close_issue() {
    local number="$1"
    gh api -X PATCH "repos/${GH_REPOSITORY}/issues/${number}" -f state=closed >/dev/null
}

function mark_stale() {
    for number in $(search_numbers "-label:lifecycle/stale -label:lifecycle/rotten updated:<$(date_before "${DAYS_UNTIL_STALE}")"); do
        echo "Marking ${GH_REPOSITORY}#${number} as lifecycle/stale"
        add_label "${number}" "lifecycle/stale"
        add_comment "${number}" "This issue or PR has been inactive for ${DAYS_UNTIL_STALE} days and is now marked as \`lifecycle/stale\`.

- After ${DAYS_UNTIL_ROTTEN}d of inactivity it will be marked as \`lifecycle/rotten\`.
- Comment \`/remove-lifecycle stale\` to remove this label.
- Comment \`/lifecycle frozen\` to exempt it from aging."
    done
}

function mark_rotten() {
    for number in $(search_numbers "label:lifecycle/stale updated:<$(date_before "${DAYS_UNTIL_ROTTEN}")"); do
        echo "Marking ${GH_REPOSITORY}#${number} as lifecycle/rotten"
        remove_label "${number}" "lifecycle/stale"
        add_label "${number}" "lifecycle/rotten"
        add_comment "${number}" "This issue or PR has been inactive for another ${DAYS_UNTIL_ROTTEN} days and is now marked as \`lifecycle/rotten\`.

- After ${DAYS_UNTIL_CLOSE}d of inactivity it will be closed.
- Comment \`/remove-lifecycle rotten\` to remove this label.
- Comment \`/lifecycle frozen\` to exempt it from aging."
    done
}

function close_rotten() {
    for number in $(search_numbers "label:lifecycle/rotten updated:<$(date_before "${DAYS_UNTIL_CLOSE}")"); do
        echo "Closing rotten ${GH_REPOSITORY}#${number}"
        add_comment "${number}" "This issue or PR has been inactive for another ${DAYS_UNTIL_CLOSE} days after being marked as \`lifecycle/rotten\`, so it is now being closed.

- Comment \`/reopen\` to reopen it.
- Comment \`/remove-lifecycle rotten\` and \`/reopen\` to restart aging."
        close_issue "${number}"
    done
}

close_rotten
mark_rotten
mark_stale
