#!/usr/bin/env bash

# Sync the "needs-ok-to-test" label on a PR, mirroring prow's trigger
# plugin trust model: PRs from untrusted (non-member) authors get the
# "needs-ok-to-test" label until a member marks them safe to test with
# the /ok-to-test command (which applies the "ok-to-test" label).
# The "ok-to-test" label is sticky across pushes.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

NEEDS_OK_TO_TEST_LABEL="needs-ok-to-test"
OK_TO_TEST_LABEL="ok-to-test"

# The author is trusted if they have an association with the repository,
# consistent with the member check used for command permissions.
if [[ "${AUTHOR_ASSOCIATION}" != "NONE" && "${AUTHOR_ASSOCIATION}" != "" ]]; then
    return 0 2>/dev/null || exit 0
fi

labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"

if grep -qxF "${OK_TO_TEST_LABEL}" <<<"${labels}"; then
    return 0 2>/dev/null || exit 0
fi

if grep -qxF "${NEEDS_OK_TO_TEST_LABEL}" <<<"${labels}"; then
    return 0 2>/dev/null || exit 0
fi

add-labels.sh "${NEEDS_OK_TO_TEST_LABEL}"

if [[ "${TYPE}" == "created" ]]; then
    comment.sh "Hi @${AUTHOR}. Thanks for your PR.

I'm waiting for a member to verify that this patch is reasonable to test. If it is, they should reply with \`/ok-to-test\`.
${DETAILS:-}"
fi
