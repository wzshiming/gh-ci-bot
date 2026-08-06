#!/usr/bin/env bash

# verify-owners.sh - Validate OWNERS and OWNERS_ALIASES files modified by a
# PR, mirroring prow's verify-owners plugin. Every changed OWNERS or
# OWNERS_ALIASES file is fetched at the PR head and checked for valid YAML
# syntax, expected structure (approvers/reviewers/labels lists, aliases map)
# and that every referenced user exists on GitHub (or is an alias defined in
# OWNERS_ALIASES). On failure the "do-not-merge/invalid-owners-file" label is
# added together with a comment describing the problems; once every modified
# file is valid again the label is removed.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

INVALID_OWNERS_LABEL="do-not-merge/invalid-owners-file"

# List of validation errors, one per line, formatted as markdown list items.
_VERIFY_OWNERS_ERRORS=""

# add_owners_error records a validation error for the final report.
function add_owners_error() {
    _VERIFY_OWNERS_ERRORS="${_VERIFY_OWNERS_ERRORS}- ${1}
"
}

# get_changed_owners_files prints the changed files of the PR whose base
# name is OWNERS or OWNERS_ALIASES, skipping removed files.
function get_changed_owners_files() {
    gh api \
        --paginate \
        "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
        --jq '.[] | select(.status != "removed") | .filename | select((split("/") | last) == "OWNERS" or (split("/") | last) == "OWNERS_ALIASES")' |
        sort -u
}

# fetch_file_at_head fetches a file from the PR head commit.
# Outputs the file content on success, fails when the file cannot be read.
function fetch_file_at_head() {
    local path="$1"
    gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${head_sha}" 2>/dev/null
}

# yaml_type prints the yq type of an expression applied to the content.
function yaml_type() {
    local content="$1"
    local expr="$2"
    printf '%s\n' "${content}" | yq e "${expr} | type" - 2>/dev/null
}

# check_string_list validates that a top-level key of an OWNERS file is a
# list of non-empty strings (or absent). Records errors on failure.
function check_string_list() {
    local file="$1"
    local content="$2"
    local key="$3"
    local t
    t="$(yaml_type "${content}" ".${key} // []")"
    if [[ "${t}" != "!!seq" ]]; then
        add_owners_error "\`${file}\`: \`${key}\` must be a list of strings."
        return 1
    fi
    local types
    types="$(printf '%s\n' "${content}" | yq e "[.${key} // [] | .[] | type] | unique | join(\" \")" - 2>/dev/null)"
    local item_type
    for item_type in ${types}; do
        if [[ "${item_type}" != "!!str" ]]; then
            add_owners_error "\`${file}\`: \`${key}\` must be a list of strings."
            return 1
        fi
    done
    return 0
}

# get_string_list prints the entries of a top-level list key, one per line.
function get_string_list() {
    local content="$1"
    local key="$2"
    printf '%s\n' "${content}" | yq e ".${key} // [] | .[]" - 2>/dev/null
}

# Aliases defined in the repository's OWNERS_ALIASES at the PR head,
# lowercased, one per line.
_OWNERS_ALIASES=""
_OWNERS_ALIASES_LOADED=""

# load_owners_aliases loads the alias names from the root OWNERS_ALIASES
# file at the PR head, if present. Must not be called in a subshell.
function load_owners_aliases() {
    if [[ -n "${_OWNERS_ALIASES_LOADED}" ]]; then
        return 0
    fi
    _OWNERS_ALIASES_LOADED="true"
    local content
    if ! content="$(fetch_file_at_head "OWNERS_ALIASES")"; then
        return 0
    fi
    _OWNERS_ALIASES="$(printf '%s\n' "${content}" | yq e '.aliases // {} | keys | .[]' - 2>/dev/null | tr '[:upper:]' '[:lower:]')"
}

# Cache of already checked users, lines: "<lowercased user> <true|false>".
_CHECKED_USERS=""

# user_exists checks that a GitHub user or organization exists.
function user_exists() {
    local user="$1"
    local lower
    lower="$(echo "${user}" | tr '[:upper:]' '[:lower:]')"
    local cached
    cached="$(echo "${_CHECKED_USERS}" | awk -v u="${lower}" '$1 == u { print $2 }')"
    if [[ -n "${cached}" ]]; then
        [[ "${cached}" == "true" ]]
        return
    fi
    local exists="false"
    if gh api "/users/${user}" >/dev/null 2>&1; then
        exists="true"
    fi
    _CHECKED_USERS="${_CHECKED_USERS}
${lower} ${exists}"
    [[ "${exists}" == "true" ]]
}

# check_users validates every user referenced in a list key of an OWNERS
# file: aliases defined in OWNERS_ALIASES are accepted, anything else must
# be an existing GitHub user. Must not be called in a subshell.
function check_users() {
    local file="$1"
    local content="$2"
    local key="$3"
    local user lower
    while read -r user; do
        if [[ -z "${user}" ]]; then
            continue
        fi
        if ! [[ "${user}" =~ ^[a-zA-Z0-9](-?[a-zA-Z0-9])*$ ]]; then
            add_owners_error "\`${file}\`: \`${user}\` in \`${key}\` is not a valid GitHub user name."
            continue
        fi
        lower="$(echo "${user}" | tr '[:upper:]' '[:lower:]')"
        load_owners_aliases
        if echo "${_OWNERS_ALIASES}" | grep -qxF "${lower}"; then
            continue
        fi
        if ! user_exists "${user}"; then
            add_owners_error "\`${file}\`: \`${user}\` in \`${key}\` is not a GitHub user or an alias defined in \`OWNERS_ALIASES\`."
        fi
    done <<<"$(get_string_list "${content}" "${key}")"
}

# verify_owners_file validates a single OWNERS file at the PR head.
function verify_owners_file() {
    local file="$1"
    local content
    if ! content="$(fetch_file_at_head "${file}")"; then
        add_owners_error "\`${file}\`: unable to fetch the file from the PR head."
        return 0
    fi

    if ! printf '%s\n' "${content}" | yq e '.' - >/dev/null 2>&1; then
        add_owners_error "\`${file}\`: invalid YAML syntax."
        return 0
    fi

    local t
    t="$(yaml_type "${content}" ".")"
    if [[ "${t}" != "!!map" && "${t}" != "!!null" ]]; then
        add_owners_error "\`${file}\`: must be a YAML map."
        return 0
    fi

    if check_string_list "${file}" "${content}" "approvers"; then
        check_users "${file}" "${content}" "approvers"
    fi
    if check_string_list "${file}" "${content}" "reviewers"; then
        check_users "${file}" "${content}" "reviewers"
    fi
    check_string_list "${file}" "${content}" "labels"
}

# verify_owners_aliases_file validates a single OWNERS_ALIASES file at the
# PR head.
function verify_owners_aliases_file() {
    local file="$1"
    local content
    if ! content="$(fetch_file_at_head "${file}")"; then
        add_owners_error "\`${file}\`: unable to fetch the file from the PR head."
        return 0
    fi

    if ! printf '%s\n' "${content}" | yq e '.' - >/dev/null 2>&1; then
        add_owners_error "\`${file}\`: invalid YAML syntax."
        return 0
    fi

    local t
    t="$(yaml_type "${content}" ".aliases // {}")"
    if [[ "${t}" != "!!map" ]]; then
        add_owners_error "\`${file}\`: \`aliases\` must be a map of alias name to list of users."
        return 0
    fi

    local alias user
    while read -r alias; do
        if [[ -z "${alias}" ]]; then
            continue
        fi
        local list_type
        list_type="$(yaml_type "${content}" ".aliases.[\"${alias}\"]")"
        if [[ "${list_type}" != "!!seq" ]]; then
            add_owners_error "\`${file}\`: alias \`${alias}\` must be a list of users."
            continue
        fi
        while read -r user; do
            if [[ -z "${user}" ]]; then
                continue
            fi
            if ! [[ "${user}" =~ ^[a-zA-Z0-9](-?[a-zA-Z0-9])*$ ]]; then
                add_owners_error "\`${file}\`: \`${user}\` in alias \`${alias}\` is not a valid GitHub user name."
                continue
            fi
            if ! user_exists "${user}"; then
                add_owners_error "\`${file}\`: \`${user}\` in alias \`${alias}\` is not a GitHub user."
            fi
        done <<<"$(printf '%s\n' "${content}" | yq e ".aliases.[\"${alias}\"] | .[]" - 2>/dev/null)"
    done <<<"$(printf '%s\n' "${content}" | yq e '.aliases // {} | keys | .[]' - 2>/dev/null)"
}

changed_files="$(get_changed_owners_files)"

info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json headRefOid,labels)"
head_sha="$(echo "${info}" | jq -r '.headRefOid')"
has_label="$(echo "${info}" | jq -r --arg l "${INVALID_OWNERS_LABEL}" '[.labels[].name] | contains([$l])')"

if [[ -z "${changed_files}" ]]; then
    if [[ "${has_label}" == "true" ]]; then
        remove-labels.sh "${INVALID_OWNERS_LABEL}"
    fi
    return 0 2>/dev/null || exit 0
fi

echo "Verifying OWNERS files changed by the PR:"
echo "${changed_files}" | sed 's/^/  - /'

while read -r file; do
    if [[ -z "${file}" ]]; then
        continue
    fi
    if [[ "${file##*/}" == "OWNERS_ALIASES" ]]; then
        verify_owners_aliases_file "${file}"
    else
        verify_owners_file "${file}"
    fi
done <<<"${changed_files}"

if [[ -n "${_VERIFY_OWNERS_ERRORS}" ]]; then
    echo "Invalid OWNERS files found:"
    printf '%s' "${_VERIFY_OWNERS_ERRORS}" | sed 's/^/  /'
    if [[ "${has_label}" != "true" ]]; then
        add-labels.sh "${INVALID_OWNERS_LABEL}"
        comment.sh "The following problems were found in the OWNERS files modified by this PR:

${_VERIFY_OWNERS_ERRORS}
Please fix them and the \`${INVALID_OWNERS_LABEL}\` label will be removed automatically.${DETAILS:-}"
    fi
else
    echo "All changed OWNERS files are valid."
    if [[ "${has_label}" == "true" ]]; then
        remove-labels.sh "${INVALID_OWNERS_LABEL}"
    fi
fi
