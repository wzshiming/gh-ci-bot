#!/usr/bin/env bash

# Sync the "do-not-merge/blocked-paths" label on a PR, mirroring prow's
# blockade plugin: the label is added with an explanatory comment while the
# PR touches any file matching one of the configured block patterns (unless
# the file also matches an exception pattern), and removed once that is no
# longer the case.
#
# Configuration (environment variables):
#   BLOCKADE_PATHS           - newline separated extended regular expressions
#                              matched against changed file paths; a match
#                              blocks the PR. Empty disables the plugin.
#   BLOCKADE_EXCEPTION_PATHS - newline separated extended regular expressions;
#                              files matching any of these are never blocked.
#   BLOCKADE_REASON          - optional human readable explanation included
#                              in the comment when the PR is blocked.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${BLOCKADE_PATHS:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

BLOCKADE_LABEL="do-not-merge/blocked-paths"

# matches_any checks whether the given path matches any of the newline
# separated extended regular expressions in the given pattern list.
function matches_any() {
    local path="$1"
    local patterns="$2"
    local pattern
    while read -r pattern; do
        if [[ -z "${pattern}" ]]; then
            continue
        fi
        if echo "${path}" | grep -qE "${pattern}"; then
            return 0
        fi
    done <<<"${patterns}"
    return 1
}

files="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[].filename' |
    sort -u)"

blocked_files=""
while read -r file; do
    if [[ -z "${file}" ]]; then
        continue
    fi
    if ! matches_any "${file}" "${BLOCKADE_PATHS}"; then
        continue
    fi
    if matches_any "${file}" "${BLOCKADE_EXCEPTION_PATHS:-}"; then
        continue
    fi
    blocked_files="${blocked_files}${file}
"
done <<<"${files}"

has_label="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq "[.labels[].name] | contains([\"${BLOCKADE_LABEL}\"])")"

if [[ -n "${blocked_files}" ]]; then
    echo "PR touches blocked paths:"
    echo "${blocked_files}"
    if [[ "${has_label}" != "true" ]]; then
        add-labels.sh "${BLOCKADE_LABEL}"
        file_list="$(echo "${blocked_files}" | sed '/^$/d;s/^/- `/;s/$/`/')"
        reason=""
        if [[ -n "${BLOCKADE_REASON:-}" ]]; then
            reason="
${BLOCKADE_REASON}
"
        fi
        comment.sh "This PR touches the following protected paths and cannot be merged:

${file_list}
${reason}
The \`${BLOCKADE_LABEL}\` label will be removed automatically once the PR no longer touches these paths."
    fi
elif [[ "${has_label}" == "true" ]]; then
    echo "PR no longer touches blocked paths, removing the '${BLOCKADE_LABEL}' label."
    remove-labels.sh "${BLOCKADE_LABEL}"
    check-auto-merge.sh
fi
