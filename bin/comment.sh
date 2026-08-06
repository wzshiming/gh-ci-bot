#!/usr/bin/env bash

body="${1}"

if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
    server_url="${GITHUB_SERVER_URL:-https://github.com}"
    repository="${GITHUB_REPOSITORY:-${GH_REPOSITORY}}"
    run_url="${server_url%/}/${repository}/actions/runs/${GITHUB_RUN_ID}"
    body="${body}

<details>
<summary>Execution log</summary>

[Open the execution log](${run_url})

</details>"
fi

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" comment "${ISSUE_NUMBER}" --body "${body}"
