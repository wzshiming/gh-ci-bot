#!/usr/bin/env bash

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --title "$*" || {
    echo "[FAIL] Failed to retitle."
    exit 1
}

# Title edits made with GITHUB_TOKEN do not trigger workflows, so sync the
# work-in-progress label right away.
check-wip.sh
