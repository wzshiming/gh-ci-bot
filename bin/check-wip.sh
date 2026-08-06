#!/usr/bin/env bash

# Sync the "do-not-merge/work-in-progress" label on a PR, mirroring prow's
# wip plugin: the label is added while the PR is a draft or its title starts
# with "WIP", and removed once that is no longer the case.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

WIP_LABEL="do-not-merge/work-in-progress"

info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json isDraft,title,labels)"

is_draft="$(echo "${info}" | jq -r '.isDraft')"
title="$(echo "${info}" | jq -r '.title')"
has_label="$(echo "${info}" | jq -r --arg l "${WIP_LABEL}" '[.labels[].name] | contains([$l])')"

wip=false
if [[ "${is_draft}" == "true" ]]; then
    wip=true
elif echo "${title}" | grep -qiE '^[[:space:][:punct:]]*WIP([[:space:][:punct:]]|$)'; then
    wip=true
fi

if [[ "${wip}" == "true" && "${has_label}" != "true" ]]; then
    # Make sure the label exists so adding it cannot fail.
    if ! gh label -R "${GH_REPOSITORY}" list --search "${WIP_LABEL}" --json name --jq '.[].name' | grep -qx "${WIP_LABEL}"; then
        gh label -R "${GH_REPOSITORY}" create "${WIP_LABEL}" --color e11d21 --description "Indicates that a PR should not merge because it is a work in progress." || true
    fi
    add-labels.sh "${WIP_LABEL}"
elif [[ "${wip}" != "true" && "${has_label}" == "true" ]]; then
    remove-labels.sh "${WIP_LABEL}"
fi
