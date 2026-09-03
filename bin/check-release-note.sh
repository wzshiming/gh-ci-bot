#!/usr/bin/env bash

# Sync the release-note labels on a PR, mirroring prow's release-note
# plugin: the ```release-note block in the PR body is classified and
# exactly one of the release-note labels is applied, with
# do-not-merge/release-note-label-needed blocking merge until the block is
# filled in (or /release-note-none is used). Labels only: this script
# never posts comments.
#
# Opt-in: does nothing unless the RELEASE_NOTE_REQUIRED environment
# variable is set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${RELEASE_NOTE_REQUIRED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

RELEASE_NOTE_LABEL="release-note"
RELEASE_NOTE_NONE_LABEL="release-note-none"
RELEASE_NOTE_NEEDED_LABEL="do-not-merge/release-note-label-needed"

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json body,labels)"; then
    # Never mutate labels from missing PR data.
    echo "Failed to get the pull request, skipping the release-note sync."
    return 0 2>/dev/null || exit 0
fi

body="$(echo "${info}" | jq -r '.body // ""')"
labels="$(echo "${info}" | jq -r '.labels[].name')"

want="$(release-note.sh <<<"${body}")"

# Prow parity: /release-note-none is sticky, an empty block never overrides it.
if [[ "${want}" == "${RELEASE_NOTE_NEEDED_LABEL}" ]] && grep -qxF "${RELEASE_NOTE_NONE_LABEL}" <<<"${labels}"; then
    want="${RELEASE_NOTE_NONE_LABEL}"
fi

for label in "${RELEASE_NOTE_LABEL}" "${RELEASE_NOTE_NONE_LABEL}" "${RELEASE_NOTE_NEEDED_LABEL}"; do
    if [[ "${label}" == "${want}" ]]; then
        if ! grep -qxF "${label}" <<<"${labels}"; then
            add-labels.sh "${label}"
        fi
    elif grep -qxF "${label}" <<<"${labels}"; then
        remove-labels.sh "${label}"
    fi
done
