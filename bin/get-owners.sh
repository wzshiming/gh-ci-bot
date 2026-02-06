#!/usr/bin/env bash

# Get owners (reviewers/approvers) from OWNERS files in the repository.
# Usage: get-owners.sh <field>
# field: "reviewers" or "approvers"
# Outputs one username per line.
#
# If the repository has OWNERS files at multiple levels, all of them are
# searched so that a user listed in any OWNERS file is included.

field="${1}"

if [[ -z "${field}" ]]; then
    echo "Usage: get-owners.sh <field>" >&2
    exit 1
fi

branch="$(gh api "/repos/${GH_REPOSITORY}" | jq -r '.default_branch')"

# List all OWNERS files in the repository using the Git tree API
owners_paths="$(gh api "/repos/${GH_REPOSITORY}/git/trees/${branch}?recursive=1" | jq -r '.tree[] | select(.path | test("(^|/)OWNERS$")) | .path')"

owners_users=""
for owners_path in ${owners_paths}; do
    result="$(curl -fsSL "https://github.com/${GH_REPOSITORY}/raw/${branch}/${owners_path}" 2>/dev/null | yq e ".${field} | .[]" 2>/dev/null)" || true
    if [[ -n "${result}" ]]; then
        owners_users="${owners_users}
${result}"
    fi
done

# Output unique, non-empty usernames
echo "${owners_users}" | grep -v '^$' | sort -u
