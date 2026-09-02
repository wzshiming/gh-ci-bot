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
#   OWNERS_LOAD_FAILED    - non-empty when the OWNERS data could not be
#                           loaded; consumers must fail closed on it

OWNERS_LOAD_FAILED=""
export OWNERS_LOAD_FAILED

# OWNERS files are read from the PR's base branch (like prow); outside a
# PR context they come from the repository default branch. A failed
# lookup marks the load failed instead of proceeding with a wrong ref.
if [[ -z "${branch:-}" ]]; then
    if [[ "${ISSUE_KIND:-}" == "pr" && -n "${ISSUE_NUMBER:-}" ]]; then
        _owners_branch_json="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName)" || _owners_branch_json=""
        branch="$(echo "${_owners_branch_json}" | jq -r '.baseRefName // empty')"
    else
        _owners_branch_json="$(gh api "/repos/${GH_REPOSITORY}")" || _owners_branch_json=""
        branch="$(echo "${_owners_branch_json}" | jq -r '.default_branch // empty')"
    fi
    unset _owners_branch_json
    if [[ -z "${branch}" ]]; then
        echo "OWNERS: failed to resolve the ref to read OWNERS files from" >&2
        OWNERS_LOAD_FAILED=1
    fi
fi
export branch

# fetch_owners_file fetches an OWNERS file from the given directory in
# the repo. Outputs the file content on success, nothing when the file
# does not exist (HTTP 404), and fails on any other error so that API
# failures are never mistaken for a missing OWNERS file.
function fetch_owners_file() {
    local dir="$1"
    local path
    local content
    local errfile
    if [[ -z "${dir}" ]]; then
        path="OWNERS"
    else
        path="${dir}/OWNERS"
    fi

    errfile="$(mktemp)"
    if ! content="$(gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${branch}" 2>"${errfile}")"; then
        if grep -q "HTTP 404" "${errfile}"; then
            rm -f "${errfile}"
            return 0
        fi
        cat "${errfile}" >&2
        rm -f "${errfile}"
        return 1
    fi
    rm -f "${errfile}"

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
# directory as if they were listed in the root OWNERS file. Fails when
# the fetch fails (other than a 404).
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
    if ! content="$(fetch_owners_file "${fetch_dir}")"; then
        return 1
    fi

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
        if ! load_owners_dir "${dir}"; then
            return 1
        fi
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
        if ! load_owners_dir "${dir}"; then
            return 1
        fi
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

# get_pr_changed_files fetches the list of changed files for the current
# PR. Fails when the fetch fails, so callers never mistake an API error
# for an empty change set.
function get_pr_changed_files() {
    local files
    if ! files="$(gh api \
        --paginate \
        "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
        --jq '.[].filename')"; then
        return 1
    fi
    echo "${files}" | sort -u
}

# mark_owners_load_failed records a hard OWNERS load failure and blanks
# every OWNERS_* result so no partial data survives; consumers
# (approve-status.sh) fail closed on it.
function mark_owners_load_failed() {
    echo "OWNERS: failed to load OWNERS data: $1" >&2
    OWNERS_AREAS=""
    OWNERS_AREA_APPROVERS=""
    OWNERS_LABELS=""
    OWNERS_LOAD_FAILED=1
    export OWNERS_AREAS OWNERS_AREA_APPROVERS OWNERS_LABELS OWNERS_LOAD_FAILED
}

# load_owners_for_pr fetches changed files, computes the changed areas,
# collects per-area approvers, and merges everything with env vars. On
# any API failure it leaves the OWNERS_* variables empty and sets
# OWNERS_LOAD_FAILED instead of failing, so command dispatch keeps
# working while approval changes fail closed.
function load_owners_for_pr() {
    OWNERS_AREAS=""
    OWNERS_AREA_APPROVERS=""
    OWNERS_LABELS=""
    export OWNERS_AREAS OWNERS_AREA_APPROVERS OWNERS_LABELS

    if [[ -n "${OWNERS_LOAD_FAILED}" ]]; then
        return 0
    fi

    local files
    if ! files="$(get_pr_changed_files)"; then
        mark_owners_load_failed "could not fetch the changed files"
        return 0
    fi

    local areas=""
    local f
    for f in ${files}; do
        if ! get_file_area "${f}"; then
            mark_owners_load_failed "could not fetch OWNERS for ${f}"
            return 0
        fi
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
        if ! collect_area_approvers "${area}"; then
            mark_owners_load_failed "could not fetch OWNERS for area ${area}"
            return 0
        fi
        OWNERS_AREA_APPROVERS="${OWNERS_AREA_APPROVERS}${area} ${_AREA_APPROVERS}
"
        all_approvers="${all_approvers} ${_AREA_APPROVERS}"
    done
    OWNERS_AREA_APPROVERS="$(echo "${OWNERS_AREA_APPROVERS}" | sed '/^$/d')"
    # A repo with no approvers in any OWNERS file (or no OWNERS at all)
    # keeps the stateless approval path: no per-area state to track.
    if echo "${OWNERS_AREA_APPROVERS}" | awk 'NF >= 2 { exit 1 }'; then
        OWNERS_AREA_APPROVERS=""
    fi
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
