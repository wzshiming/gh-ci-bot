#!/usr/bin/env bash

# Approve workflow runs that are awaiting approval from a maintainer for the
# PR's head commit, so workflows of external contributors run automatically.
# https://docs.github.com/actions/managing-workflow-runs/approving-workflow-runs-from-public-forks

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

workflow_run_list="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/actions/runs?status=action_required&per_page=100&head_sha=${head_sha}")"

workflow_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | select(.status == "action_required") | .id')"

for workflow_run_id in ${workflow_run_ids}; do
    if [[ "${workflow_run_id}" == "" ]]; then
        continue
    fi
    echo "Approving workflow run ID: ${workflow_run_id}"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/approve" | cat || echo "Failed to approve https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}"
done
