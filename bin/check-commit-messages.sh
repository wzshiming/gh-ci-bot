#!/usr/bin/env bash

# Sync the "do-not-merge/invalid-commit-message" label on a PR, mirroring
# prow's invalidcommitmsg plugin: the label is added while any commit
# message or the PR title contains an @mention or a keyword which can
# automatically close issues (e.g. "fixes #42"), and removed once they
# are fixed. Labels only: this script never posts comments.
#
# Opt-in: does nothing unless the BLOCK_INVALID_COMMIT_MESSAGES
# environment variable is set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${BLOCK_INVALID_COMMIT_MESSAGES:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

INVALID_COMMIT_MESSAGE_LABEL="do-not-merge/invalid-commit-message"

# Keywords which can automatically close issues when the PR is merged
# (e.g. "fixes #42" or "closes org/repo#42"), and @mentions, which would
# notify the user from the resulting commit. They mirror prow's
# CloseIssueRegex and AtMentionRegex.
CLOSE_ISSUE_REGEX='(clos(e[sd]?)|fix(es|ed)?|resolv(e[sd]?))[[:space:]:]+([[:alnum:]_]+/[[:alnum:]_]+)?#[0-9]+'
AT_MENTION_REGEX='(^|[^[:alnum:]_])@[[:alnum:]_-]+'

# is_invalid checks whether the given text contains an issue-closing
# keyword or an @mention.
function is_invalid() {
    grep -qiE "${CLOSE_ISSUE_REGEX}" <<<"${1}" || grep -qE "${AT_MENTION_REGEX}" <<<"${1}"
}

if ! messages="$(gh api \
    --paginate \
    "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/commits" \
    --jq '.[].commit.message')"; then
    # Never mutate labels from missing commit data.
    echo "Failed to get the pull request commits, skipping the commit-messages sync."
    return 0 2>/dev/null || exit 0
fi

if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json title,labels)"; then
    # Never mutate labels from missing PR data.
    echo "Failed to get the pull request, skipping the commit-messages sync."
    return 0 2>/dev/null || exit 0
fi

title="$(echo "${info}" | jq -r '.title')"
has_label="$(echo "${info}" | jq -r --arg l "${INVALID_COMMIT_MESSAGE_LABEL}" 'any(.labels[].name; . == $l)')"

invalid=false
if is_invalid "${messages}"; then
    echo "A commit message contains an issue-closing keyword or an @mention."
    invalid=true
fi
if is_invalid "${title}"; then
    echo "The PR title contains an issue-closing keyword or an @mention."
    invalid=true
fi

if [[ "${invalid}" == "true" && "${has_label}" != "true" ]]; then
    add-labels.sh "${INVALID_COMMIT_MESSAGE_LABEL}"
elif [[ "${invalid}" != "true" && "${has_label}" == "true" ]]; then
    remove-labels.sh "${INVALID_COMMIT_MESSAGE_LABEL}"
fi
