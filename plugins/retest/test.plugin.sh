#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

target="$1"

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

workflow_run_list="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/actions/runs?per_page=100&head_sha=${head_sha}")"

available="$(echo "${workflow_run_list}" | jq -r '[.workflow_runs | .[] | .name] | unique | join(", ")')"

if [[ "${target}" == "" ]]; then
    echo "[FAIL] Usage: \`/test <workflow-or-job>\` or \`/test all\`. Available workflows: ${available}."
    exit 1
fi

function rerun_workflow_run() {
    local workflow_run_id="$1"
    echo "Workflow run ID: ${workflow_run_id}"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/rerun" | cat
}

function rerun_workflow_job() {
    local workflow_job_id="$1"
    echo "Workflow job ID: ${workflow_job_id}"
    gh api \
        --method POST \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/jobs/${workflow_job_id}/rerun" | cat
}

failed=()

if [[ "${target}" == "all" ]]; then
    workflow_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | .id')"
    for workflow_run_id in ${workflow_run_ids}; do
        if [[ "${workflow_run_id}" == "" ]]; then
            continue
        fi
        rerun_workflow_run "${workflow_run_id}" || failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
    done

    if [[ "${workflow_run_ids}" == "" ]]; then
        echo "[FAIL] No workflow runs found for this pull request."
        exit 1
    fi
else
    # Match a workflow by its name or by its workflow file name
    workflow_run_ids="$(echo "${workflow_run_list}" | jq -r --arg target "${target}" \
        '.workflow_runs | .[] | select((.name == $target) or ((.path // "" | split("/") | last) == $target)) | .id')"

    if [[ "${workflow_run_ids}" != "" ]]; then
        for workflow_run_id in ${workflow_run_ids}; do
            rerun_workflow_run "${workflow_run_id}" || failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
        done
    else
        # Fall back to matching a job by its name within the workflow runs
        all_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | .id')"
        found_job="false"
        for workflow_run_id in ${all_run_ids}; do
            workflow_job_ids="$(gh api \
                -H "Accept: application/vnd.github+json" \
                "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/jobs?per_page=100" |
                jq -r --arg target "${target}" '.jobs | .[] | select(.name == $target) | .id')"
            for workflow_job_id in ${workflow_job_ids}; do
                found_job="true"
                echo "Workflow run ID: ${workflow_run_id}"
                rerun_workflow_job "${workflow_job_id}" || failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
            done
        done

        if [[ "${found_job}" == "false" ]]; then
            echo "[FAIL] No workflow or job named \`${target}\` found for this pull request. Available workflows: ${available}."
            exit 1
        fi
    fi
fi

if [[ ${#failed[@]} -eq 0 ]]; then
    echo "All were re-requested"
else
    echo "Failed to re-request:"
    for fail in "${failed[@]}"; do
        echo "  - ${fail}"
    done
fi
