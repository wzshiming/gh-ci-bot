#!/usr/bin/env bash

# Sync the "size/*" label on a PR, mirroring prow's size plugin: the PR is
# labeled with one of size/XS, size/S, size/M, size/L, size/XL or size/XXL
# based on the total number of changed lines (additions + deletions),
# updating the label whenever the PR changes.
#
# Generated files are excluded from the count, like prow's size plugin:
#   - files marked "linguist-generated" in the ".gitattributes" file at the
#     repository root (the same attribute GitHub uses to hide generated
#     files in diffs)
#   - files matched by an optional ".generated_files" file at the
#     repository root. Each non-comment line of that file has the form
#     "<kind> <value>" where <kind> is one of:
#       file-name   - matches files with the given base name
#       path        - matches the exact file path
#       file-prefix - matches files whose base name starts with the value
#       path-prefix - matches files whose path starts with the value

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

# size_label prints the size/* label for the given number of changed lines.
# Thresholds mirror prow's size plugin defaults.
function size_label() {
    local lines="$1"
    if [[ "${lines}" -lt 10 ]]; then
        echo "size/XS"
    elif [[ "${lines}" -lt 30 ]]; then
        echo "size/S"
    elif [[ "${lines}" -lt 100 ]]; then
        echo "size/M"
    elif [[ "${lines}" -lt 500 ]]; then
        echo "size/L"
    elif [[ "${lines}" -lt 1000 ]]; then
        echo "size/XL"
    else
        echo "size/XXL"
    fi
}

# is_generated_file checks a file path against the rules loaded from
# .generated_files. Rules are provided via the generated_rules variable.
function is_generated_file() {
    local file="$1"
    local base="${file##*/}"
    local kind value
    while read -r kind value; do
        case "${kind}" in
        file-name)
            if [[ "${base}" == "${value}" ]]; then
                return 0
            fi
            ;;
        path)
            if [[ "${file}" == "${value}" ]]; then
                return 0
            fi
            ;;
        file-prefix)
            if [[ "${base}" == "${value}"* ]]; then
                return 0
            fi
            ;;
        path-prefix)
            if [[ "${file}" == "${value}"* ]]; then
                return 0
            fi
            ;;
        esac
    done <<<"${generated_rules}"
    return 1
}

# gitattributes_pattern_to_regex converts a gitattributes (gitignore-style)
# pattern to an anchored extended regex. Sets _PATTERN_REGEX.
function gitattributes_pattern_to_regex() {
    local pattern="$1"
    local regex=""
    local i c
    for ((i = 0; i < ${#pattern}; i++)); do
        c="${pattern:i:1}"
        case "${c}" in
        \*)
            if [[ "${pattern:i:3}" == "**/" ]]; then
                regex+="(.*/)?"
                i=$((i + 2))
            elif [[ "${pattern:i:2}" == "**" ]]; then
                regex+=".*"
                i=$((i + 1))
            else
                regex+="[^/]*"
            fi
            ;;
        \?)
            regex+="[^/]"
            ;;
        . | \\ | \+ | \( | \) | \[ | \] | \{ | \} | \^ | \$ | \|)
            regex+="\\${c}"
            ;;
        *)
            regex+="${c}"
            ;;
        esac
    done
    _PATTERN_REGEX="^${regex}$"
}

# is_linguist_generated checks a file path against the linguist-generated
# rules loaded from .gitattributes; the last matching rule wins, like git.
# Rules are provided via the gitattributes_rules variable.
function is_linguist_generated() {
    local file="$1"
    local base="${file##*/}"
    local generated=1
    local pattern attrs attr
    while read -r pattern attrs; do
        if [[ -z "${pattern}" || "${pattern}" == \#* ]]; then
            continue
        fi
        local matched=1
        if [[ "${pattern}" == */* ]]; then
            gitattributes_pattern_to_regex "${pattern#/}"
            if [[ "${file}" =~ ${_PATTERN_REGEX} ]]; then
                matched=0
            fi
        else
            gitattributes_pattern_to_regex "${pattern}"
            if [[ "${base}" =~ ${_PATTERN_REGEX} ]]; then
                matched=0
            fi
        fi
        if [[ "${matched}" -ne 0 ]]; then
            continue
        fi
        for attr in ${attrs}; do
            case "${attr}" in
            linguist-generated | linguist-generated=true)
                generated=0
                ;;
            -linguist-generated | linguist-generated=false)
                generated=1
                ;;
            esac
        done
    done <<<"${gitattributes_rules}"
    return "${generated}"
}

# fetch_root_file fetches a file from the root of the repository at the
# base branch, outputting nothing if the file does not exist.
function fetch_root_file() {
    gh api \
        --method GET \
        -H "Accept: application/vnd.github.raw+json" \
        "/repos/${GH_REPOSITORY}/contents/${1}" \
        -f "ref=${base_branch}" 2>/dev/null | tr -d '\r'
}

base_branch="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName --jq '.baseRefName')"

generated_rules="$(fetch_root_file ".generated_files" |
    sed 's/#.*//' | sed '/^[[:space:]]*$/d')"

gitattributes_rules="$(fetch_root_file ".gitattributes" |
    grep 'linguist-generated')"

total=0
while read -r additions deletions file; do
    if [[ -z "${file}" ]]; then
        continue
    fi
    if [[ -n "${generated_rules}" ]] && is_generated_file "${file}"; then
        echo "Ignoring generated file: ${file}"
        continue
    fi
    if [[ -n "${gitattributes_rules}" ]] && is_linguist_generated "${file}"; then
        echo "Ignoring linguist-generated file: ${file}"
        continue
    fi
    total=$((total + additions + deletions))
done < <(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[] | "\(.additions) \(.deletions) \(.filename)"')

want="$(size_label "${total}")"

current="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name | select(startswith("size/"))')"

echo "PR changes ${total} lines, size label: ${want}"

for label in ${current}; do
    if [[ "${label}" != "${want}" ]]; then
        remove-labels.sh "${label}"
    fi
done

if ! grep -qxF "${want}" <<<"${current}"; then
    add-labels.sh "${want}"
fi
