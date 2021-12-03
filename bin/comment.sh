#!/usr/bin/env bash

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" comment "${ISSUE_NUMBER}" --body "${1}"
