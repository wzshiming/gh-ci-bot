#!/usr/bin/env bash

# Validate OWNERS and OWNERS_ALIASES files changed in a PR, mirroring prow's
# verify-owners plugin: every added or modified OWNERS/OWNERS_ALIASES file is
# checked for valid YAML syntax, expected structure and that every referenced
# user exists on GitHub (or is an alias defined in OWNERS_ALIASES). The
# "do-not-merge/invalid-owners-file" label is added while any file is invalid
# and removed once all files are valid again. Any label starting with
# "do-not-merge/" already blocks both "/merge" and auto-merge.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

INVALID_OWNERS_LABEL="do-not-merge/invalid-owners-file"

# List added or modified OWNERS/OWNERS_ALIASES files in the PR.
changed_owners_files="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[] | select(.status != "removed") | .filename' |
    grep -E '(^|/)(OWNERS|OWNERS_ALIASES)$' | sort -u || true)"

has_label="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq \
    '[.labels[].name] | contains(["'"${INVALID_OWNERS_LABEL}"'"])')"

if [[ -z "${changed_owners_files}" ]]; then
    if [[ "${has_label}" == "true" ]]; then
        remove-labels.sh "${INVALID_OWNERS_LABEL}"
    fi
    return 0 2>/dev/null || exit 0
fi

head_sha="$(gh api "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" --jq '.head.sha')"

# fetch_pr_file fetches a file from the PR head. Outputs the file content on
# success, empty on failure.
function fetch_pr_file() {
    local path="$1"
    gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${head_sha}" 2>/dev/null || true
}

# Aliases defined in the PR head OWNERS_ALIASES file are accepted wherever a
# user is expected in OWNERS files.
known_aliases="$(fetch_pr_file "OWNERS_ALIASES" | yq e '.aliases // {} | keys | .[]' 2>/dev/null || true)"

_USERS_CHECKED=""
_USERS_INVALID=""

# check_user_exists verifies a GitHub user or alias exists, caching results.
# Returns non-zero for unknown users.
function check_user_exists() {
    local user="$1"
    if echo "${known_aliases}" | grep -qixF "${user}"; then
        return 0
    fi
    if echo "${_USERS_CHECKED}" | grep -qixF "${user}"; then
        if echo "${_USERS_INVALID}" | grep -qixF "${user}"; then
            return 1
        fi
        return 0
    fi
    _USERS_CHECKED="${_USERS_CHECKED}
${user}"
    if ! gh api "/users/${user}" --jq '.login' >/dev/null 2>&1; then
        _USERS_INVALID="${_USERS_INVALID}
${user}"
        return 1
    fi
    return 0
}

errors=""

# add_error records a validation error for a file.
function add_error() {
    local file="$1"
    local message="$2"
    errors="${errors}
- \`${file}\`: ${message}"
}

# verify_users checks that every entry in a list of users is a valid GitHub
# user or a known alias.
function verify_users() {
    local file="$1"
    local kind="$2"
    local users="$3"
    local user
    for user in ${users}; do
        if ! check_user_exists "${user}"; then
            add_error "${file}" "unknown ${kind} \`${user}\`: not a GitHub user or a defined alias"
        fi
    done
}

# verify_owners_file validates a single OWNERS file.
function verify_owners_file() {
    local file="$1"
    local content="$2"

    if ! echo "${content}" | yq e '.' >/dev/null 2>&1; then
        add_error "${file}" "invalid YAML syntax"
        return 0
    fi

    if [[ "$(echo "${content}" | yq e 'tag' 2>/dev/null)" != "!!map" ]]; then
        add_error "${file}" "must be a YAML map with \`approvers\` and/or \`reviewers\` lists"
        return 0
    fi

    local key tag
    for key in approvers reviewers; do
        tag="$(echo "${content}" | yq e ".${key} | tag" 2>/dev/null)"
        if [[ "${tag}" != "!!null" && "${tag}" != "!!seq" ]]; then
            add_error "${file}" "\`${key}\` must be a list of users"
        fi
    done

    verify_users "${file}" "approver" "$(echo "${content}" | yq e '.approvers // [] | .[]' 2>/dev/null)"
    verify_users "${file}" "reviewer" "$(echo "${content}" | yq e '.reviewers // [] | .[]' 2>/dev/null)"
}

# verify_owners_aliases_file validates a single OWNERS_ALIASES file.
function verify_owners_aliases_file() {
    local file="$1"
    local content="$2"

    if ! echo "${content}" | yq e '.' >/dev/null 2>&1; then
        add_error "${file}" "invalid YAML syntax"
        return 0
    fi

    if [[ "$(echo "${content}" | yq e '.aliases | tag' 2>/dev/null)" != "!!map" ]]; then
        add_error "${file}" "must contain an \`aliases\` map of alias name to list of users"
        return 0
    fi

    local alias tag
    while read -r alias; do
        [[ -z "${alias}" ]] && continue
        tag="$(echo "${content}" | yq e ".aliases.\"${alias}\" | tag" 2>/dev/null)"
        if [[ "${tag}" != "!!seq" ]]; then
            add_error "${file}" "alias \`${alias}\` must be a list of users"
            continue
        fi
        verify_users "${file}" "user in alias \`${alias}\`" "$(echo "${content}" | yq e ".aliases.\"${alias}\" | .[]" 2>/dev/null)"
    done <<<"$(echo "${content}" | yq e '.aliases | keys | .[]' 2>/dev/null)"
}

for file in ${changed_owners_files}; do
    echo "Verifying ${file}"
    content="$(fetch_pr_file "${file}")"
    if [[ -z "${content}" ]]; then
        add_error "${file}" "unable to fetch the file from the PR head"
        continue
    fi
    if [[ "${file##*/}" == "OWNERS_ALIASES" ]]; then
        verify_owners_aliases_file "${file}" "${content}"
    else
        verify_owners_file "${file}" "${content}"
    fi
done

if [[ -n "${errors}" ]]; then
    echo "Invalid OWNERS files found:"
    echo "${errors}"
    # Make sure the label exists so adding it cannot fail.
    if ! gh label -R "${GH_REPOSITORY}" list --search "${INVALID_OWNERS_LABEL}" --json name --jq '.[].name' | grep -qx "${INVALID_OWNERS_LABEL}"; then
        gh label -R "${GH_REPOSITORY}" create "${INVALID_OWNERS_LABEL}" --color e11d21 --description "Indicates that a PR should not merge because it touches an OWNERS file in an invalid way." || true
    fi
    if [[ "${has_label}" != "true" ]]; then
        add-labels.sh "${INVALID_OWNERS_LABEL}"
        comment.sh "@${AUTHOR:-${LOGIN}} This PR modifies \`OWNERS\` or \`OWNERS_ALIASES\` files that failed validation:
${errors}

Please fix the problems above; the \`${INVALID_OWNERS_LABEL}\` label will be removed automatically once all files are valid."
    fi
else
    echo "All changed OWNERS files are valid."
    if [[ "${has_label}" == "true" ]]; then
        remove-labels.sh "${INVALID_OWNERS_LABEL}"
    fi
fi
