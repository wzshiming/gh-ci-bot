#!/usr/bin/env bash

# Sync the needs-rebase label on a PR, mirroring prow's needs-rebase
# external plugin: a PR that has merge conflicts with the base branch
# gets the needs-rebase label and a comment asking the author to rebase,
# and once the conflicts are resolved the label is removed and the stale
# comments are pruned automatically. Complements the /rebase command.
#
# Opt-in: does nothing unless the NEEDS_REBASE environment variable is
# set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${NEEDS_REBASE:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

NEEDS_REBASE_LABEL="needs-rebase"
NEEDS_REBASE_MARKER="PR needs rebase."

# GitHub computes mergeability asynchronously, so shortly after a push it
# reports UNKNOWN for a while; poll a few times to let it settle.
state=""
mergeable=""
labels=""
for try in 1 2 3 4 5; do
    if [[ "${try}" -ne 1 ]]; then
        sleep 5
    fi
    if ! info="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json mergeable,state,labels)"; then
        # Never mutate labels from missing PR data.
        echo "Failed to get the pull request, skipping the needs-rebase sync."
        return 0 2>/dev/null || exit 0
    fi
    state="$(echo "${info}" | jq -r '.state')"
    mergeable="$(echo "${info}" | jq -r '.mergeable')"
    labels="$(echo "${info}" | jq -r '.labels[].name')"
    if [[ "${state}" != "OPEN" || "${mergeable}" != "UNKNOWN" ]]; then
        break
    fi
done

# Closed and merged PRs never need a rebase.
if [[ "${state}" != "OPEN" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ "${mergeable}" == "CONFLICTING" ]]; then
    if ! grep -qxF "${NEEDS_REBASE_LABEL}" <<<"${labels}"; then
        add-labels.sh "${NEEDS_REBASE_LABEL}"
        comment.sh "@${AUTHOR}: ${NEEDS_REBASE_MARKER}

This PR has merge conflicts with the base branch. Please rebase it onto the latest base branch, resolve the conflicts and push the result; the \`${NEEDS_REBASE_LABEL}\` label will be removed automatically once the PR is mergeable again.
${DETAILS:-}"
    fi
elif [[ "${mergeable}" == "MERGEABLE" ]]; then
    if grep -qxF "${NEEDS_REBASE_LABEL}" <<<"${labels}"; then
        remove-labels.sh "${NEEDS_REBASE_LABEL}"
        # The conflicts are gone; prune the now stale rebase requests.
        BOT_LOGIN="$(bot-login.sh)"
        gh api "/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/comments" |
            jq -r --arg bot "${BOT_LOGIN}" --arg marker "${NEEDS_REBASE_MARKER}" \
                '.[] | select(.user.login == $bot) | select(.body | contains($marker)) | .id' |
            xargs -I {} gh api "/repos/${GH_REPOSITORY}/issues/comments/{}" --silent -X DELETE
    fi
else
    echo "Mergeability of the pull request is not known yet, skipping the needs-rebase sync."
fi
