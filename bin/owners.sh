#!/usr/bin/env bash

# owners.sh - Utility to fetch and parse OWNERS files from the repository.
#
# OWNERS files are used hierarchically. For pull requests, every changed
# file is mapped to its "area": the nearest ancestor directory (up to the
# root, represented as ".") whose OWNERS file lists at least one approver.
# For each area, the approvers of the area itself and of all its parent
# directories are collected, so owners of a parent directory can always
# approve nested areas. Reviewers are collected from every OWNERS file
# visited along the way. The collected values are merged with the
# REVIEWERS and APPROVERS environment variables.
#
# Exports:
#   OWNERS_AREAS          - newline separated list of changed areas
#   OWNERS_AREA_APPROVERS - lines of "<area> <approver>...", one per area

branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"
export branch

# fetch_owners_file fetches an OWNERS file from the given directory in the repo.
# Outputs the file content on success, empty on failure.
function fetch_owners_file() {
    local dir="$1"
    local path
    local content
    if [[ -z "${dir}" ]]; then
        path="OWNERS"
    else
        path="${dir}/OWNERS"
    fi

    if ! content="$(gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${branch}" 2>/dev/null)"; then
        return 0
    fi

    printf '%s\n' "${content}"
}

# get_owners_reviewers extracts reviewers from an OWNERS file content.
function get_owners_reviewers() {
    echo "$1" | yq e '.reviewers // [] | .[]' 2>/dev/null
}

# get_owners_approvers extracts approvers from an OWNERS file content.
function get_owners_approvers() {
    echo "$1" | yq e '.approvers // [] | .[]' 2>/dev/null
}

# Caches for directories already checked. The root directory is ".".
_OWNERS_CHECKED=""
_OWNERS_DIR_APPROVERS="" # lines: "<dir> <user>..."
_OWNERS_DIR_REVIEWERS="" # lines: "<dir> <user>..."

# get_parent_dir prints the parent of a directory, "." for top-level
# directories and nothing for ".".
function get_parent_dir() {
    local dir="$1"
    if [[ "${dir}" == "." ]]; then
        echo ""
    elif [[ "${dir}" =~ "/" ]]; then
        echo "${dir%/*}"
    else
        echo "."
    fi
}

# load_owners_dir fetches the OWNERS file of a directory once and caches
# its approvers and reviewers. Env APPROVERS are merged into the root
# directory as if they were listed in the root OWNERS file.
# Must not be called in a subshell.
function load_owners_dir() {
    local dir="$1"
    if echo "${_OWNERS_CHECKED}" | grep -qxF "${dir}"; then
        return 0
    fi
    _OWNERS_CHECKED="${_OWNERS_CHECKED}
${dir}"

    local fetch_dir=""
    if [[ "${dir}" != "." ]]; then
        fetch_dir="${dir}"
    fi

    local content
    content="$(fetch_owners_file "${fetch_dir}")"

    local a r
    a="$(get_owners_approvers "${content}")"
    r="$(get_owners_reviewers "${content}")"

    if [[ "${dir}" == "." ]]; then
        a="${a}
${APPROVERS:-}"
    fi

    a="$(echo "${a}" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    r="$(echo "${r}" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
    if [[ -n "${a}" ]]; then
        _OWNERS_DIR_APPROVERS="${_OWNERS_DIR_APPROVERS}
${dir} ${a}"
    fi
    if [[ -n "${r}" ]]; then
        _OWNERS_DIR_REVIEWERS="${_OWNERS_DIR_REVIEWERS}
${dir} ${r}"
    fi
}

# get_dir_approvers prints the cached approvers of a directory.
function get_dir_approvers() {
    local dir="$1"
    echo "${_OWNERS_DIR_APPROVERS}" | awk -v d="${dir}" '$1 == d { $1 = ""; print substr($0, 2) }'
}

# get_file_area finds the area of a changed file: the nearest ancestor
# directory with approvers in its OWNERS file, or ".". Sets _FILE_AREA.
function get_file_area() {
    local file="$1"
    local dir
    if [[ "${file}" =~ "/" ]]; then
        dir="${file%/*}"
    else
        dir="."
    fi

    while true; do
        load_owners_dir "${dir}"
        if [[ -n "$(get_dir_approvers "${dir}")" ]]; then
            _FILE_AREA="${dir}"
            return 0
        fi
        if [[ "${dir}" == "." ]]; then
            _FILE_AREA="."
            return 0
        fi
        dir="$(get_parent_dir "${dir}")"
    done
}

# collect_area_approvers collects approvers of an area and of all its
# parent directories. Sets _AREA_APPROVERS.
function collect_area_approvers() {
    local dir="$1"
    local users=""
    while true; do
        load_owners_dir "${dir}"
        local a
        a="$(get_dir_approvers "${dir}")"
        if [[ -n "${a}" ]]; then
            users="${users} ${a}"
        fi
        if [[ "${dir}" == "." ]]; then
            break
        fi
        dir="$(get_parent_dir "${dir}")"
    done
    _AREA_APPROVERS="$(echo ${users} | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
}

# get_pr_changed_files fetches the list of changed files for the current PR.
function get_pr_changed_files() {
    gh api \
        --paginate \
        "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
        --jq '.[].filename' |
        sort -u
}

# load_owners_for_pr fetches changed files, computes the changed areas,
# collects per-area approvers, and merges everything with env vars.
function load_owners_for_pr() {
    local files
    files="$(get_pr_changed_files)"

    local areas=""
    local f
    for f in ${files}; do
        get_file_area "${f}"
        areas="${areas}
${_FILE_AREA}"
    done
    areas="$(echo "${areas}" | sed '/^$/d' | sort -u)"

    OWNERS_AREAS="${areas}"
    export OWNERS_AREAS

    OWNERS_AREA_APPROVERS=""
    local all_approvers=""
    local area
    for area in ${areas}; do
        collect_area_approvers "${area}"
        OWNERS_AREA_APPROVERS="${OWNERS_AREA_APPROVERS}${area} ${_AREA_APPROVERS}
"
        all_approvers="${all_approvers} ${_AREA_APPROVERS}"
    done
    OWNERS_AREA_APPROVERS="$(echo "${OWNERS_AREA_APPROVERS}" | sed '/^$/d')"
    export OWNERS_AREA_APPROVERS

    echo "OWNERS: changed areas:" >&2
    echo "${OWNERS_AREA_APPROVERS}" | while read -r area_name users; do
        echo "  - ${area_name}: ${users:-<no approvers>}" >&2
    done

    OWNERS_APPROVERS="$(echo ${all_approvers} | tr ' ' '\n' | sed '/^$/d' | sort -u)"
    OWNERS_REVIEWERS="$(echo "${_OWNERS_DIR_REVIEWERS}" | sed '/^$/d' | awk '{ $1 = ""; print substr($0, 2) }' | tr ' ' '\n' | sed '/^$/d' | sort -u)"

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
