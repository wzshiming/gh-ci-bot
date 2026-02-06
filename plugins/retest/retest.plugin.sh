#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

head_sha="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" | jq -r '.head.sha')"

check_suite_list="$(gh api \
    -H "Accept: application/vnd.github+json" \
    "/repos/${GH_REPOSITORY}/commits/${head_sha}/check-suites?per_page=100")"

check_suite_ids="$(echo "${check_suite_list}" | jq -r '.check_suites | .[] | select(.conclusion == "failure") | .id')"

failed=()
for check_suite_id in ${check_suite_ids}; do
    workflow_run_list="$(gh api \
        -H "Accept: application/vnd.github+json" \
        "/repos/${GH_REPOSITORY}/actions/runs?status=failure&per_page=100&check_suite_id=${check_suite_id}")"

    workflow_run_ids="$(echo "${workflow_run_list}" | jq -r '.workflow_runs | .[] | select(.conclusion == "failure") | .id')"

    for workflow_run_id in ${workflow_run_ids}; do
        if [[ "${workflow_run_id}" == "" ]]; then
            continue
        fi
        echo "Check suite ID: ${check_suite_id}"
        echo "Workflow run ID: ${workflow_run_id}"
        gh api \
            --method POST \
            -H "Accept: application/vnd.github+json" \
            "/repos/${GH_REPOSITORY}/actions/runs/${workflow_run_id}/rerun-failed-jobs" | cat || failed+=("https://github.com/${GH_REPOSITORY}/actions/runs/${workflow_run_id}")
    done
done

if [[ ${#failed[@]} -eq 0 ]]; then
    echo "All were re-requested"
else
    echo "Failed to re-request:"
    for fail in "${failed[@]}"; do
        echo "  - ${fail}"
    done
fi
