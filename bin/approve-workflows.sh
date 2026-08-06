#!/usr/bin/env bash

# approve-workflows.sh - Approve workflow runs of a PR that are awaiting
# approval from a maintainer (e.g. runs from public forks of first-time
# contributors), mirroring prow's ok-to-test plugin.
#
# Requires the `actions: write` permission on the token.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

workflow_run_list="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/actions/runs?status=action_required&per_page=100&head_sha=${head_sha}")"

workflow_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | .id')"

if [[ "${workflow_run_ids}" == "" ]]; then
    echo "No workflow runs awaiting approval"
    exit 0
fi

failed=()
for workflow_run_id in ${workflow_run_ids}; do
    echo "Approving workflow run ID: ${workflow_run_id}"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/approve" | cat || failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
done

if [[ ${#failed[@]} -eq 0 ]]; then
    echo "All pending workflow runs were approved"
else
    echo "[FAIL] Failed to approve workflow runs:"
    for fail in "${failed[@]}"; do
        echo "  - ${fail}"
    done
fi
