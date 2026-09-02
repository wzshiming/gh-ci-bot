#!/usr/bin/env bash

# Approve all workflow runs of the current PR's head commit that are
# waiting for approval (status "action_required"), automating the
# "Approve and run" button GitHub shows for runs of first-time
# contributors. Requires the actions: write permission.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

if [[ "${head_sha}" == "" || "${head_sha}" == "null" ]]; then
    # Never approve workflow runs without a head SHA to scope them to.
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

workflow_run_list="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/actions/runs?status=action_required&per_page=100&head_sha=${head_sha}")"

workflow_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | .id')"

if [[ "${workflow_run_ids}" == "" ]]; then
    echo "No workflow runs are waiting for approval"
    return 0 2>/dev/null || exit 0
fi

failed=()
for workflow_run_id in ${workflow_run_ids}; do
    if [[ "${workflow_run_id}" == "" ]]; then
        continue
    fi
    echo "Approve workflow run ID: ${workflow_run_id}"
    if ! gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/approve"; then
        # The approve endpoint only accepts runs of fork pull requests;
        # held runs of same-repo pull requests are started by a rerun.
        echo "Approve rejected, falling back to rerun for workflow run ID: ${workflow_run_id}"
        gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/rerun" ||
            failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
    fi
done

if [[ ${#failed[@]} -eq 0 ]]; then
    echo "All were approved"
else
    echo "Failed to approve:"
    for fail in "${failed[@]}"; do
        echo "  - ${fail}"
    done
fi
