#!/usr/bin/env bash

# owners.sh - Utility to fetch and parse OWNERS files from the repository.
#
# OWNERS files are used hierarchically. For pull requests, every changed
# file is mapped to its "area": the nearest ancestor directory (up to the
# root, represented as ".") whose OWNERS file lists at least one approver.
# For each area, the approvers of the area itself and of all its parent
# directories are collected, so owners of a parent directory can always
# approve nested areas. Reviewers and labels are collected from every
# OWNERS file visited along the way. The collected values are merged with
# the REVIEWERS and APPROVERS environment variables.
#
# Exports:
#   OWNERS_AREAS          - newline separated list of changed areas
#   OWNERS_AREA_APPROVERS - lines of "<area> <approver>...", one per area
#   OWNERS_LABELS         - newline separated list of labels declared in
#                           the OWNERS files of the changed directories
#   OWNERS_LOAD_FAILED    - non-empty when loading failed; fail closed on it

export OWNERS_LOAD_FAILED=""

# OWNERS files come from the PR's base branch, else the default branch.
if [[ -z "${branch:-}" ]]; then
    if [[ "${ISSUE_KIND:-}" == "pr" && -n "${ISSUE_NUMBER:-}" ]]; then
        branch="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName --jq '.baseRefName')" || branch=""
    else
        branch="$(gh api "/repos/${GH_REPOSITORY}" --jq '.default_branch')" || branch=""
    fi
    [[ -n "${branch}" ]] || export OWNERS_LOAD_FAILED=1
fi
export branch

# fetch_owners_file prints the OWNERS file of a directory: nothing when it
# does not exist (HTTP 404), failure on any other error.
function fetch_owners_file() {
    local path="${1:+$1/}OWNERS"
    local err content rc msg
    err="$(mktemp)"
    content="$(gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${branch}" 2>"${err}")"
    rc=$?
    msg="$(cat "${err}")"
    rm -f "${err}"
    if [[ ${rc} -ne 0 ]]; then
        [[ "${msg}" == *"HTTP 404"* ]] && return 0
        echo "${msg}" >&2
        return 1
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

# get_owners_labels extracts labels from an OWNERS file content.
function get_owners_labels() {
    echo "$1" | yq e '.labels // [] | .[]' 2>/dev/null
}

# Caches for directories already checked. The root directory is ".".
_OWNERS_CHECKED=""
_OWNERS_DIR_APPROVERS="" # lines: "<dir> <user>..."
_OWNERS_DIR_REVIEWERS="" # lines: "<dir> <user>..."
_OWNERS_LABELS=""        # lines: one label per line (labels may contain spaces)

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
    content="$(fetch_owners_file "${fetch_dir}")" || return 1

    local a r l
    a="$(get_owners_approvers "${content}")"
    r="$(get_owners_reviewers "${content}")"
    l="$(get_owners_labels "${content}")"

    if [[ -n "${l}" ]]; then
        _OWNERS_LABELS="${_OWNERS_LABELS}
${l}"
    fi

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
        load_owners_dir "${dir}" || return 1
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
        load_owners_dir "${dir}" || return 1
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
    gh api --paginate "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" --jq '.[].filename' | sort -u
    return "${PIPESTATUS[0]}"
}

# load_owners_for_pr fetches changed files, computes the changed areas,
# collects per-area approvers, and merges everything with env vars. Any
# API failure sets OWNERS_LOAD_FAILED (consumers fail closed) rather than
# aborting, so command dispatch keeps working.
function load_owners_for_pr() {
    export OWNERS_AREAS="" OWNERS_AREA_APPROVERS="" OWNERS_LABELS=""
    if [[ -z "${OWNERS_LOAD_FAILED}" ]] && ! compute_owners_for_pr; then
        echo "OWNERS: failed to load OWNERS data" >&2
        export OWNERS_AREAS="" OWNERS_AREA_APPROVERS="" OWNERS_LABELS="" OWNERS_LOAD_FAILED=1
    fi
}

function compute_owners_for_pr() {
    local files
    files="$(get_pr_changed_files)" || return 1

    local areas=""
    local f
    for f in ${files}; do
        get_file_area "${f}" || return 1
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
        collect_area_approvers "${area}" || return 1
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

    OWNERS_LABELS="$(echo "${_OWNERS_LABELS}" | sed '/^$/d' | sort -u)"
    export OWNERS_LABELS

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
