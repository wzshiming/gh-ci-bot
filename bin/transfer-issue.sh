#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "issue" ]]; then
    echo "[FAIL] This command is only available on issues, not on pull requests."
    exit 1
fi

repo="${1:-}"

if [[ "${repo}" == "" ]]; then
    echo "[FAIL] Missing required argument: repository name. Usage: \`/transfer-issue <repo>\`"
    exit 1
fi

org="${GH_REPOSITORY%%/*}"

# Allow both `repo` and `org/repo` forms, but only within the same organization
if [[ "${repo}" == */* ]]; then
    if [[ "${repo%%/*}" != "${org}" ]]; then
        echo "[FAIL] Issues can only be transferred to repositories in the same organization \`${org}\`."
        exit 1
    fi
    repo="${repo#*/}"
fi

target_repo="${org}/${repo}"

if [[ "${target_repo}" == "${GH_REPOSITORY}" ]]; then
    echo "[FAIL] The issue is already in \`${GH_REPOSITORY}\`. Please specify a different repository."
    exit 1
fi

if ! gh api "/repos/${target_repo}" --silent; then
    echo "[FAIL] The repository \`${target_repo}\` does not exist or is not accessible."
    exit 1
fi

gh issue transfer -R "${GH_REPOSITORY}" "${ISSUE_NUMBER}" "${target_repo}" ||
    echo "[FAIL] Failed to transfer the issue to \`${target_repo}\`. Please verify the repository and try again."
