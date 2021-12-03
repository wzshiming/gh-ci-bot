#!/usr/bin/env bash

gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" reopen "${ISSUE_NUMBER}"
