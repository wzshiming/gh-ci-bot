#!/usr/bin/env bash

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    echo "[FAIL] This command is only available on pull requests, not on issues."
    exit 1
fi

RELEASE_NOTE_LABEL="release-note"
RELEASE_NOTE_NONE_LABEL="release-note-none"
RELEASE_NOTE_NEEDED_LABEL="do-not-merge/release-note-label-needed"

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json body,labels)"; then
    # Never mutate labels from missing PR data.
    echo "[FAIL] Failed to get the pull request."
    exit 1
fi

body="$(echo "${info}" | jq -r '.body // ""')"
labels="$(echo "${info}" | jq -r '.labels[].name')"

# Prow-style: a release note in the PR body takes precedence over the command.
if [[ "$(release-note.sh <<<"${body}")" == "${RELEASE_NOTE_LABEL}" ]]; then
    echo "[FAIL] The \`release-note\` block in the PR body contains a release note, which takes precedence over \`/release-note-none\`. Please change the block content to \`NONE\` instead."
    exit 1
fi

if ! grep -qxF "${RELEASE_NOTE_NONE_LABEL}" <<<"${labels}"; then
    add-labels.sh "${RELEASE_NOTE_NONE_LABEL}"
fi
if grep -qxF "${RELEASE_NOTE_LABEL}" <<<"${labels}"; then
    remove-labels.sh "${RELEASE_NOTE_LABEL}"
fi
if grep -qxF "${RELEASE_NOTE_NEEDED_LABEL}" <<<"${labels}"; then
    remove-labels.sh "${RELEASE_NOTE_NEEDED_LABEL}"
fi
