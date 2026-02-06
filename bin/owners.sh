#!/usr/bin/env bash

# OWNERS file utilities for gh-ci-bot
# Parses OWNERS files and provides reviewers/approvers lists
# OWNERS files are YAML files with 'reviewers' and 'approvers' lists

# Get the default branch of the repository
function get_default_branch() {
    if [[ -n "${DEFAULT_BRANCH:-}" ]]; then
        echo "${DEFAULT_BRANCH}"
        return
    fi
    gh api "/repos/${GH_REPOSITORY}" | jq -r '.default_branch'
}

# Read an OWNERS file from a given directory path
# Usage: read_owners_file <dir_path> <field>
# field: "reviewers" or "approvers"
function read_owners_file() {
    local dir="${1}"
    local field="${2}"
    local branch
    branch="$(get_default_branch)"
    local url="https://github.com/${GH_REPOSITORY}/raw/${branch}/${dir}/OWNERS"
    
    if [[ "${dir}" == "" || "${dir}" == "." ]]; then
        url="https://github.com/${GH_REPOSITORY}/raw/${branch}/OWNERS"
    fi
    
    echo "Reading OWNERS from ${url}" >&2
    curl -fsSL "${url}" 2>/dev/null | yq e ".${field} | .[]" 2>/dev/null
}

# Get the parent directory of a path
function get_parent_dir() {
    local dir="${1}"
    if [[ "${dir}" =~ "/" ]]; then
        echo "${dir%/*}"
    else
        echo ""
    fi
}

# Find common prefix directory of multiple paths
# Usage: get_common_prefix <path1> <path2> ...
function get_common_prefix() {
    local paths=("$@")
    
    if [[ ${#paths[@]} -eq 0 ]]; then
        echo ""
        return
    fi
    
    if [[ ${#paths[@]} -eq 1 ]]; then
        get_parent_dir "${paths[0]}"
        return
    fi
    
    # Get the first path's directory as the starting point
    local prefix
    prefix="$(get_parent_dir "${paths[0]}")"
    
    # Compare with all other paths
    for path in "${paths[@]:1}"; do
        local path_dir
        path_dir="$(get_parent_dir "${path}")"
        
        # Find common prefix between current prefix and path_dir
        while [[ -n "${prefix}" ]]; do
            if [[ "${path_dir}" == "${prefix}" || "${path_dir}" == "${prefix}/"* ]]; then
                break
            fi
            prefix="$(get_parent_dir "${prefix}")"
        done
    done
    
    echo "${prefix}"
}

# Collect owners walking up from a directory to root
# Usage: collect_owners_from_path <start_dir> <field>
# Returns: newline-separated list of users
function collect_owners_from_path() {
    local dir="${1}"
    local field="${2}"
    local collected=()
    local seen_dirs=()
    
    # Walk up from the directory to root
    while true; do
        # Check if we've already processed this directory
        local already_seen=false
        for seen in "${seen_dirs[@]}"; do
            if [[ "${dir}" == "${seen}" ]]; then
                already_seen=true
                break
            fi
        done
        
        if [[ "${already_seen}" == "false" ]]; then
            seen_dirs+=("${dir}")
            local users
            users="$(read_owners_file "${dir}" "${field}")"
            if [[ -n "${users}" ]]; then
                while IFS= read -r user; do
                    if [[ -n "${user}" ]]; then
                        # Check if user is already collected
                        local exists=false
                        for u in "${collected[@]}"; do
                            if [[ "${u}" == "${user}" ]]; then
                                exists=true
                                break
                            fi
                        done
                        if [[ "${exists}" == "false" ]]; then
                            collected+=("${user}")
                        fi
                    fi
                done <<< "${users}"
            fi
        fi
        
        # Move to parent directory
        if [[ -z "${dir}" || "${dir}" == "." ]]; then
            break
        fi
        local parent
        parent="$(get_parent_dir "${dir}")"
        if [[ "${parent}" == "${dir}" ]]; then
            break
        fi
        dir="${parent}"
    done
    
    # Output collected users
    for u in "${collected[@]}"; do
        echo "${u}"
    done
}

# Get all reviewers for a list of files
# Usage: get_reviewers_for_files <file1> <file2> ...
# Returns: newline-separated list of reviewers merged with REVIEWERS env var
function get_reviewers_for_files() {
    local files=("$@")
    local all_reviewers=()
    
    # Get common prefix of all files
    local common_prefix
    common_prefix="$(get_common_prefix "${files[@]}")"
    
    echo "Common prefix for changed files: ${common_prefix:-<root>}" >&2
    
    # Collect reviewers from common prefix up to root
    local owners_reviewers
    owners_reviewers="$(collect_owners_from_path "${common_prefix}" "reviewers")"
    
    while IFS= read -r user; do
        if [[ -n "${user}" ]]; then
            all_reviewers+=("${user}")
        fi
    done <<< "${owners_reviewers}"
    
    # Merge with REVIEWERS environment variable
    if [[ -n "${REVIEWERS:-}" ]]; then
        while IFS= read -r user; do
            if [[ -n "${user}" ]]; then
                local exists=false
                for u in "${all_reviewers[@]}"; do
                    if [[ "${u}" == "${user}" ]]; then
                        exists=true
                        break
                    fi
                done
                if [[ "${exists}" == "false" ]]; then
                    all_reviewers+=("${user}")
                fi
            fi
        done <<< "${REVIEWERS}"
    fi
    
    # Output all reviewers
    for u in "${all_reviewers[@]}"; do
        echo "${u}"
    done
}

# Get all approvers for a list of files
# Usage: get_approvers_for_files <file1> <file2> ...
# Returns: newline-separated list of approvers merged with APPROVERS env var
function get_approvers_for_files() {
    local files=("$@")
    local all_approvers=()
    
    # Get common prefix of all files
    local common_prefix
    common_prefix="$(get_common_prefix "${files[@]}")"
    
    echo "Common prefix for changed files: ${common_prefix:-<root>}" >&2
    
    # Collect approvers from common prefix up to root
    local owners_approvers
    owners_approvers="$(collect_owners_from_path "${common_prefix}" "approvers")"
    
    while IFS= read -r user; do
        if [[ -n "${user}" ]]; then
            all_approvers+=("${user}")
        fi
    done <<< "${owners_approvers}"
    
    # Merge with APPROVERS environment variable
    if [[ -n "${APPROVERS:-}" ]]; then
        while IFS= read -r user; do
            if [[ -n "${user}" ]]; then
                local exists=false
                for u in "${all_approvers[@]}"; do
                    if [[ "${u}" == "${user}" ]]; then
                        exists=true
                        break
                    fi
                done
                if [[ "${exists}" == "false" ]]; then
                    all_approvers+=("${user}")
                fi
            fi
        done <<< "${APPROVERS}"
    fi
    
    # Output all approvers
    for u in "${all_approvers[@]}"; do
        echo "${u}"
    done
}

# Get reviewer for a specific file by walking up to nearest OWNERS file
# Used by auto-cc to find the nearest reviewer for each changed file
# Usage: get_reviewer_for_file <file_path> <exclude_users>
# Returns: single reviewer username or empty
function get_reviewer_for_file() {
    local file="${1}"
    shift
    local exclude_users=("$@")
    local dir
    dir="$(get_parent_dir "${file}")"
    
    while true; do
        local users
        users="$(read_owners_file "${dir}" "reviewers")"
        
        if [[ -n "${users}" ]]; then
            # Shuffle and find first available user
            for user in $(echo "${users}" | sort --random-sort); do
                local excluded=false
                for ex in "${exclude_users[@]}"; do
                    if [[ "${user}" == "${ex}" ]]; then
                        excluded=true
                        break
                    fi
                done
                if [[ "${excluded}" == "false" ]]; then
                    echo "${user}"
                    return 0
                fi
            done
        fi
        
        # Move to parent
        if [[ -z "${dir}" || "${dir}" == "." ]]; then
            break
        fi
        local parent
        parent="$(get_parent_dir "${dir}")"
        if [[ "${parent}" == "${dir}" ]]; then
            break
        fi
        dir="${parent}"
    done
    
    echo ""
}

# Get list of files changed in a PR
# Usage: get_pr_changed_files
# Returns: newline-separated list of file paths
function get_pr_changed_files() {
    local branch
    branch="$(get_default_branch)"
    curl -fsSL "https://github.com/${GH_REPOSITORY}/pull/${ISSUE_NUMBER}.patch" |
        grep '^[-+]\{3\} [ab]' |
        sed "s#--- a/##g" |
        sed "s#+++ b/##g" |
        sort -u
}
