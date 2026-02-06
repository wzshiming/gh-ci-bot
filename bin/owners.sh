#!/usr/bin/env bash

# owners.sh - Utility to fetch and parse OWNERS files from the repository.
#
# OWNERS files are used hierarchically. For pull requests, this script
# determines the common prefix directory of all changed files and walks
# up from there to the root, collecting reviewers and approvers from
# every OWNERS file found along the way. The collected values are merged
# with the REVIEWERS and APPROVERS environment variables.

branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"

# get_common_prefix computes the longest common directory prefix of all
# changed files in a pull request.
function get_common_prefix() {
    local files="$1"
    local prefix=""
    local first=true

    for f in ${files}; do
        local dir
        if [[ "${f}" =~ "/" ]]; then
            dir="${f%/*}"
        else
            dir=""
        fi

        if ${first}; then
            prefix="${dir}"
            first=false
            continue
        fi

        # Find common prefix between current prefix and this dir
        while [[ "${prefix}" != "" && "${dir}" != "${prefix}" && "${dir}" != "${prefix}"/* ]]; do
            if [[ "${prefix}" =~ "/" ]]; then
                prefix="${prefix%/*}"
            else
                prefix=""
            fi
        done
    done

    echo "${prefix}"
}

# fetch_owners_file fetches an OWNERS file from the given directory in the repo.
# Outputs the file content on success, empty on failure.
function fetch_owners_file() {
    local dir="$1"
    local path
    if [[ -z "${dir}" ]]; then
        path="OWNERS"
    else
        path="${dir}/OWNERS"
    fi
    curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${path}" 2>/dev/null
}

# get_owners_reviewers extracts reviewers from an OWNERS file content.
function get_owners_reviewers() {
    echo "$1" | yq e '.reviewers // [] | .[]' 2>/dev/null
}

# get_owners_approvers extracts approvers from an OWNERS file content.
function get_owners_approvers() {
    echo "$1" | yq e '.approvers // [] | .[]' 2>/dev/null
}

# collect_owners_from_prefix walks from the given directory up to the root,
# collecting reviewers and approvers from every OWNERS file found.
# Sets OWNERS_REVIEWERS and OWNERS_APPROVERS variables.
function collect_owners_from_prefix() {
    local dir="$1"
    local reviewers=""
    local approvers=""

    while true; do
        local content
        content="$(fetch_owners_file "${dir}")"
        if [[ -n "${content}" ]]; then
            local r a
            r="$(get_owners_reviewers "${content}")"
            a="$(get_owners_approvers "${content}")"
            if [[ -n "${r}" ]]; then
                reviewers="${reviewers}
${r}"
            fi
            if [[ -n "${a}" ]]; then
                approvers="${approvers}
${a}"
            fi
        fi

        if [[ -z "${dir}" ]]; then
            break
        fi

        if [[ "${dir}" =~ "/" ]]; then
            dir="${dir%/*}"
        else
            dir=""
        fi
    done

    OWNERS_REVIEWERS="$(echo "${reviewers}" | sed '/^$/d' | sort -u)"
    OWNERS_APPROVERS="$(echo "${approvers}" | sed '/^$/d' | sort -u)"
}

# get_pr_changed_files fetches the list of changed files for the current PR.
function get_pr_changed_files() {
    curl -fsSL "https://github.com/${GH_REPOSITORY}/pull/${ISSUE_NUMBER}.patch" |
        grep '^[-+]\{3\} [ab]' |
        sed "s#--- a/##g" |
        sed "s#+++ b/##g" |
        sort -u
}

# load_owners_for_pr fetches changed files, computes common prefix,
# collects OWNERS, and merges with env vars.
function load_owners_for_pr() {
    local files
    files="$(get_pr_changed_files)"

    local prefix
    prefix="$(get_common_prefix "${files}")"

    echo "OWNERS: common prefix of changed files: '${prefix}'" >&2

    collect_owners_from_prefix "${prefix}"

    if [[ -n "${OWNERS_REVIEWERS}" ]]; then
        echo "OWNERS reviewers:" >&2
        echo "${OWNERS_REVIEWERS}" | while read -r u; do
            echo "  - ${u}" >&2
        done
    fi

    if [[ -n "${OWNERS_APPROVERS}" ]]; then
        echo "OWNERS approvers:" >&2
        echo "${OWNERS_APPROVERS}" | while read -r u; do
            echo "  - ${u}" >&2
        done
    fi

    # Merge with environment variables
    if [[ -n "${OWNERS_REVIEWERS}" ]]; then
        REVIEWERS="$(echo "${REVIEWERS}
${OWNERS_REVIEWERS}" | sed '/^$/d' | sort -u)"
        export REVIEWERS
    fi

    if [[ -n "${OWNERS_APPROVERS}" ]]; then
        APPROVERS="$(echo "${APPROVERS}
${OWNERS_APPROVERS}" | sed '/^$/d' | sort -u)"
        export APPROVERS
    fi
}
