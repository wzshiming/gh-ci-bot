#!/usr/bin/env bash

# Sync the "size/*" label on a PR, mirroring prow's size plugin: the PR is
# labeled with one of size/XS, size/S, size/M, size/L, size/XL or size/XXL
# based on the total number of changed lines (additions + deletions),
# updating the label whenever the PR changes.
#
# Files matched by an optional ".generated_files" file at the repository
# root are excluded from the count. Each non-comment line of that file has
# the form "<kind> <value>" where <kind> is one of:
#   file-name   - matches files with the given base name
#   path        - matches the exact file path
#   file-prefix - matches files whose base name starts with the value
#   path-prefix - matches files whose path starts with the value

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

base_branch="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json baseRefName --jq '.baseRefName')"

generated_rules="$(gh api \
    --method GET \
    -H "Accept: application/vnd.github.raw+json" \
    "/repos/${GH_REPOSITORY}/contents/.generated_files" \
    -f "ref=${base_branch}" 2>/dev/null |
    sed 's/#.*//' | sed '/^[[:space:]]*$/d')"

total=0
while read -r additions deletions file; do
    if [[ -z "${file}" ]]; then
        continue
    fi
    if [[ -n "${generated_rules}" ]] && is_generated_file "${file}"; then
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
