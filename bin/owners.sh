#!/usr/bin/env bash

# owners.sh - Utility to fetch and parse OWNERS files from the repository.
#
# OWNERS files are used hierarchically. For pull requests, every changed
# file is mapped to its "area": the nearest ancestor directory (up to the
# root, represented as ".") whose OWNERS file lists at least one approver
# applicable to the file. For each area, the approvers of the area itself
# and of all its parent directories are collected, so owners of a parent
# directory can always approve nested areas. Reviewers and labels are
# collected from every OWNERS file visited along the way. The collected
# values are merged with the REVIEWERS and APPROVERS environment variables.
#
# Supported OWNERS features (see https://www.kubernetes.dev/docs/guide/owners/):
#   reviewers / approvers / labels - plain lists
#   emeritus_approvers             - excluded from the approvers list
#   filters                        - map of regex to reviewers/approvers/labels
#                                    applied per changed file (path relative to
#                                    the OWNERS file directory)
#   options.no_parent_owners       - parent OWNERS files are ignored
# An OWNERS_ALIASES file at the repository root may define aliases usable
# in any reviewers/approvers/emeritus_approvers list.
#
# Exports:
#   OWNERS_AREAS          - newline separated list of changed areas
#   OWNERS_AREA_APPROVERS - lines of "<area> <approver>...", one per area
#   OWNERS_LABELS         - newline separated list of labels declared in
#                           the OWNERS files of the changed directories

branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"
export branch

# fetch_repo_file fetches a file from the repo at the given path.
# Outputs the file content on success, empty on failure.
function fetch_repo_file() {
    local path="$1"
    local content
    if ! content="$(gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${path}" \
        -f "ref=${branch}" 2>/dev/null)"; then
        return 0
    fi

    printf '%s\n' "${content}"
}

# fetch_owners_file fetches an OWNERS file from the given directory in the repo.
# Outputs the file content on success, empty on failure.
function fetch_owners_file() {
    local dir="$1"
    if [[ -z "${dir}" ]]; then
        fetch_repo_file "OWNERS"
    else
        fetch_repo_file "${dir}/OWNERS"
    fi
}

# Caches for directories already checked. The root directory is ".".
_OWNERS_CHECKED=""
_OWNERS_DIR_JSON=""     # lines: "<dir>\t<compact OWNERS json>"
_OWNERS_ALIASES_JSON="" # compact json map of alias -> [users], loaded lazily

# load_owners_aliases fetches the OWNERS_ALIASES file at the repository
# root once and caches its aliases as a compact JSON map.
function load_owners_aliases() {
    if [[ -n "${_OWNERS_ALIASES_JSON}" ]]; then
        return 0
    fi
    local content
    content="$(fetch_repo_file "OWNERS_ALIASES")"
    _OWNERS_ALIASES_JSON="$(printf '%s\n' "${content}" | yq e -o=json -I=0 '.aliases // {}' 2>/dev/null)"
    if [[ -z "${_OWNERS_ALIASES_JSON}" || "${_OWNERS_ALIASES_JSON}" == "null" ]]; then
        _OWNERS_ALIASES_JSON="{}"
    fi
}

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
# its content as compact JSON. Must not be called in a subshell.
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

    local content json
    content="$(fetch_owners_file "${fetch_dir}")"
    json="$(printf '%s\n' "${content}" | yq e -o=json -I=0 '.' 2>/dev/null)"
    if [[ -z "${json}" || "${json}" == "null" ]]; then
        json="{}"
    fi

    _OWNERS_DIR_JSON="${_OWNERS_DIR_JSON}
${dir}	${json}"
}

# get_dir_json prints the cached OWNERS JSON of a directory.
function get_dir_json() {
    local dir="$1"
    echo "${_OWNERS_DIR_JSON}" | awk -F'\t' -v d="${dir}" '$1 == d { print $2 }'
}

# get_file_users prints the users (or labels) of the given field declared
# in the OWNERS file of a directory that apply to a changed file: the
# top-level list plus the lists of every "filters" entry whose regex
# matches the file path relative to the directory. Aliases are expanded
# and emeritus_approvers are excluded from approvers.
# Usage: get_file_users <dir> <file> <reviewers|approvers|labels>
function get_file_users() {
    local dir="$1"
    local file="$2"
    local field="$3"
    local json rel aliases
    json="$(get_dir_json "${dir}")"
    if [[ -z "${json}" ]]; then
        return 0
    fi
    if [[ "${dir}" == "." ]]; then
        rel="${file}"
    else
        rel="${file#${dir}/}"
    fi
    aliases="${_OWNERS_ALIASES_JSON}"
    if [[ -z "${aliases}" ]]; then
        aliases="{}"
    fi
    jq -r --arg rel "${rel}" --arg field "${field}" --argjson aliases "${aliases}" '
        def expand: if $field == "labels" then . else [ .[] as $n | ($aliases[$n] // [$n])[] ] end;
        ([ (.[$field] // [])[],
           ((.filters // {}) | to_entries[] | .key as $re | select(try ($rel | test($re)) catch false) | (.value[$field] // [])[])
         ] | expand) as $users
        | ((.emeritus_approvers // []) | expand) as $emeritus
        | (if $field == "approvers" then ($users - $emeritus) else $users end)
        | unique | .[]
    ' <<<"${json}" 2>/dev/null
}

# dir_no_parent_owners succeeds when the OWNERS file of a directory sets
# options.no_parent_owners, meaning parent OWNERS files must be ignored.
function dir_no_parent_owners() {
    local dir="$1"
    local json
    json="$(get_dir_json "${dir}")"
    if [[ -z "${json}" ]]; then
        return 1
    fi
    jq -e '.options.no_parent_owners == true' <<<"${json}" >/dev/null 2>&1
}

# Accumulators filled by collect_file_owners.
_OWNERS_REVIEWERS_ACC=""
_OWNERS_LABELS=""

# collect_file_owners walks up from a changed file to the repository root,
# collecting the approvers, reviewers and labels applicable to the file
# from every OWNERS file along the way. The walk stops early when an
# OWNERS file sets options.no_parent_owners. Env APPROVERS are merged
# into the root directory as if they were listed in the root OWNERS file.
# Sets _FILE_AREA (the nearest directory with applicable approvers, or
# ".") and _FILE_APPROVERS. Must not be called in a subshell.
function collect_file_owners() {
    local file="$1"
    local dir
    if [[ "${file}" =~ "/" ]]; then
        dir="${file%/*}"
    else
        dir="."
    fi

    load_owners_aliases

    local area=""
    local users=""
    local a r l
    while true; do
        load_owners_dir "${dir}"
        a="$(get_file_users "${dir}" "${file}" "approvers")"
        r="$(get_file_users "${dir}" "${file}" "reviewers")"
        l="$(get_file_users "${dir}" "${file}" "labels")"

        if [[ -n "${r}" ]]; then
            _OWNERS_REVIEWERS_ACC="${_OWNERS_REVIEWERS_ACC}
${r}"
        fi
        if [[ -n "${l}" ]]; then
            _OWNERS_LABELS="${_OWNERS_LABELS}
${l}"
        fi

        if [[ "${dir}" == "." ]]; then
            a="${a}
${APPROVERS:-}"
            a="$(echo "${a}" | sed '/^$/d')"
        fi

        if [[ -n "${a}" ]]; then
            users="${users}
${a}"
            if [[ -z "${area}" ]]; then
                area="${dir}"
            fi
        fi

        if [[ "${dir}" == "." ]]; then
            break
        fi
        if dir_no_parent_owners "${dir}"; then
            echo "OWNERS: ${dir} sets no_parent_owners, ignoring parent OWNERS files" >&2
            break
        fi
        dir="$(get_parent_dir "${dir}")"
    done

    _FILE_AREA="${area:-.}"
    _FILE_APPROVERS="$(echo "${users}" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
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
    local file_area_approvers=""
    local f
    for f in ${files}; do
        collect_file_owners "${f}"
        areas="${areas}
${_FILE_AREA}"
        file_area_approvers="${file_area_approvers}${_FILE_AREA} ${_FILE_APPROVERS}
"
    done
    areas="$(echo "${areas}" | sed '/^$/d' | sort -u)"

    OWNERS_AREAS="${areas}"
    export OWNERS_AREAS

    OWNERS_AREA_APPROVERS=""
    local all_approvers=""
    local area users
    for area in ${areas}; do
        users="$(echo "${file_area_approvers}" | awk -v a="${area}" '$1 == a { $1 = ""; print substr($0, 2) }' |
            tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
        OWNERS_AREA_APPROVERS="${OWNERS_AREA_APPROVERS}${area} ${users}
"
        all_approvers="${all_approvers} ${users}"
    done
    OWNERS_AREA_APPROVERS="$(echo "${OWNERS_AREA_APPROVERS}" | sed '/^$/d')"
    export OWNERS_AREA_APPROVERS

    echo "OWNERS: changed areas:" >&2
    echo "${OWNERS_AREA_APPROVERS}" | while read -r area_name users; do
        echo "  - ${area_name}: ${users:-<no approvers>}" >&2
    done

    OWNERS_APPROVERS="$(echo ${all_approvers} | tr ' ' '\n' | sed '/^$/d' | sort -u)"
    OWNERS_REVIEWERS="$(echo "${_OWNERS_REVIEWERS_ACC}" | tr ' ' '\n' | sed '/^$/d' | sort -u)"

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
