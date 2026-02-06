#!/usr/bin/env bash

# Loads reviewers and approvers from OWNERS files along the common prefix path
# of changed files in a PR, and merges them with REVIEWERS/APPROVERS env vars.
#
# Usage: source owners.sh
# After sourcing, REVIEWERS and APPROVERS env vars will include users from OWNERS files.

function owners_get_parent() {
    local dir="${1}"
    if [[ "${dir}" =~ "/" ]]; then
        echo "${dir%/*}"
    else
        echo ""
    fi
}

function owners_common_prefix() {
    local files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        echo ""
        return
    fi

    # Get the directory of the first file
    local prefix
    prefix="$(owners_get_parent "${files[0]}")"

    for f in "${files[@]}"; do
        local dir
        dir="$(owners_get_parent "${f}")"

        # Reduce prefix until it matches the start of dir
        while [[ "${prefix}" != "" && "${dir}/" != "${prefix}/"* ]]; do
            prefix="$(owners_get_parent "${prefix}")"
        done
    done

    echo "${prefix}"
}

function owners_fetch_field() {
    local dir="${1}"
    local field="${2}"
    curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${dir}/OWNERS" 2>/dev/null | yq e ".${field} | .[]" 2>/dev/null
}

function owners_collect_from_path() {
    local dir="${1}"
    local field="${2}"
    local collected=""

    while true; do
        local values
        values="$(owners_fetch_field "${dir}" "${field}")"
        if [[ -n "${values}" ]]; then
            collected="${collected}
${values}"
        fi

        if [[ -z "${dir}" ]]; then
            break
        fi
        dir="$(owners_get_parent "${dir}")"
    done

    echo "${collected}" | sed '/^$/d' | sort -u
}

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

branch="$(gh api /repos/${GH_REPOSITORY} --jq '.default_branch')"

# Get changed files from the PR
owners_files="$(curl -fsSL "https://github.com/${GH_REPOSITORY}/pull/${ISSUE_NUMBER}.patch" 2>/dev/null | grep '^[-\+]\{3\} [ab]' | sed "s#--- a/##g" | sed "s#+++ b/##g" | sort -u)"

if [[ -z "${owners_files}" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Find common prefix directory of all changed files
owners_prefix="$(owners_common_prefix ${owners_files})"

echo "OWNERS: common prefix directory: '${owners_prefix}'" >&2

# Collect reviewers and approvers from OWNERS files along the path
owners_reviewers="$(owners_collect_from_path "${owners_prefix}" "reviewers")"
owners_approvers="$(owners_collect_from_path "${owners_prefix}" "approvers")"

# Merge with existing env vars
if [[ -n "${owners_reviewers}" ]]; then
    echo "OWNERS: found reviewers: $(echo "${owners_reviewers}" | tr '\n' ' ')" >&2
    REVIEWERS="$(echo "${REVIEWERS}
${owners_reviewers}" | sed '/^$/d' | sort -u)"
    export REVIEWERS
fi

if [[ -n "${owners_approvers}" ]]; then
    echo "OWNERS: found approvers: $(echo "${owners_approvers}" | tr '\n' ' ')" >&2
    APPROVERS="$(echo "${APPROVERS}
${owners_approvers}" | sed '/^$/d' | sort -u)"
    export APPROVERS
fi

# Cleanup temporary variables
unset owners_files owners_prefix owners_reviewers owners_approvers
