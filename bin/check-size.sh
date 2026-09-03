#!/usr/bin/env bash

# Sync the "size/*" label on a PR, mirroring prow's size plugin: the PR is
# labeled with one of size/XS, size/S, size/M, size/L, size/XL or size/XXL
# based on the total number of changed lines (additions + deletions),
# updating the label whenever the PR changes.

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

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json additions,deletions,labels)"; then
    # Never mutate labels from missing PR data.
    echo "Failed to get the pull request, skipping the size sync."
    return 0 2>/dev/null || exit 0
fi

total="$(echo "${info}" | jq -r '.additions + .deletions')"

# An empty or null count would silently label the PR size/XS.
if [[ ! "${total}" =~ ^[0-9]+$ ]]; then
    echo "Failed to get the changed lines, skipping the size sync."
    return 0 2>/dev/null || exit 0
fi

want="$(size_label "${total}")"

current="$(echo "${info}" | jq -r '.labels[].name | select(startswith("size/"))')"

echo "PR changes ${total} lines, size label: ${want}"

while read -r label; do
    if [[ -z "${label}" ]]; then
        continue
    fi
    if [[ "${label}" != "${want}" ]]; then
        remove-labels.sh "${label}"
    fi
done <<<"${current}"

if ! grep -qxF "${want}" <<<"${current}"; then
    add-labels.sh "${want}"
fi
