#!/usr/bin/env bash

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --title "$*"

# Title edits made with GITHUB_TOKEN do not trigger workflows, so sync the
# work-in-progress label right away.
check-wip.sh
