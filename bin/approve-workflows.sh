#!/usr/bin/env bash

# approve-workflows.sh - Automatically approve workflow runs that are
# pending maintainer approval on pull requests from public forks.
#
# Workflows triggered by `pull_request` from first-time contributors sit in
# the "action_required" state until a maintainer approves them. Since the
# bot itself runs on `pull_request_target`, it can approve those runs
# automatically for harmless changes.
#
# Enabled by setting AUTO_APPROVE_WORKFLOWS=true. As a safety measure,
# pull requests that modify files under `.github/` (workflows, actions,
# bot configuration) are never auto-approved and still require a manual
# approval from a maintainer.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "${AUTO_APPROVE_WORKFLOWS:-}" != "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

changed_files="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" \
    --jq '.[].filename')"

if echo "${changed_files}" | grep -q -e '^\.github/'; then
    echo "PR modifies files under .github/, skipping workflow auto-approval"
    return 0 2>/dev/null || exit 0
fi

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

workflow_run_ids="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/actions/runs?status=action_required&head_sha=${head_sha}&per_page=100" |
    jq -r '.workflow_runs | .[] | .id')"

for workflow_run_id in ${workflow_run_ids}; do
    if [[ "${workflow_run_id}" == "" ]]; then
        continue
    fi
    echo "Approving workflow run ${workflow_run_id}"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/approve" | cat ||
        echo "Failed to approve workflow run: https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}"
done
