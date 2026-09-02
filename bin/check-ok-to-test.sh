#!/usr/bin/env bash

# Sync the ok-to-test trust gate on a PR, mirroring prow's trigger plugin:
# a PR opened by an untrusted author — one whose author association is not
# OWNER/MEMBER/COLLABORATOR and who is not listed in REVIEWERS/APPROVERS/
# MAINTAINERS — gets the needs-ok-to-test label and a comment asking a
# reviewer for /ok-to-test. The ok-to-test label is sticky: while it is
# present, workflow runs waiting for approval are approved automatically
# on every push.
#
# Opt-in: the gate does nothing unless the OK_TO_TEST_REQUIRED environment
# variable is set to a non-empty value. The sticky approval works whenever
# the ok-to-test label is present, no matter how it got there.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

OK_TO_TEST_LABEL="ok-to-test"
NEEDS_OK_TO_TEST_LABEL="needs-ok-to-test"

if ! labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"; then
    # Never gate or approve from missing PR data.
    echo "Failed to get the pull request, skipping the ok-to-test sync."
    return 0 2>/dev/null || exit 0
fi

# A vouched PR has its pending workflow runs approved automatically until
# the ok-to-test label is removed.
if grep -qxF "${OK_TO_TEST_LABEL}" <<<"${labels}"; then
    approve-workflow-runs.sh
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${OK_TO_TEST_REQUIRED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

# The gate is only applied when the PR is opened; there is no need to ask
# for /ok-to-test again on every push.
if [[ "${TYPE}" != "created" ]]; then
    return 0 2>/dev/null || exit 0
fi

if grep -qxF "${NEEDS_OK_TO_TEST_LABEL}" <<<"${labels}"; then
    return 0 2>/dev/null || exit 0
fi

# author_trusted mirrors prow's trust model: the author is trusted when
# their author association is OWNER/MEMBER/COLLABORATOR, or they are
# listed in REVIEWERS/APPROVERS/MAINTAINERS.
function author_trusted() {
    case "${AUTHOR_ASSOCIATION}" in
    OWNER | MEMBER | COLLABORATOR)
        return 0
        ;;
    esac

    if [[ -z "${AUTHOR}" ]]; then
        return 1
    fi

    local list
    for list in "${REVIEWERS:-}" "${APPROVERS:-}" "${MAINTAINERS:-}"; do
        if grep -qxF "${AUTHOR}" <<<"${list}"; then
            return 0
        fi
    done

    return 1
}

if author_trusted; then
    return 0 2>/dev/null || exit 0
fi

add-labels.sh "${NEEDS_OK_TO_TEST_LABEL}"

comment.sh "Hi @${AUTHOR}. Thanks for your PR.

I'm waiting for a reviewer to verify that this patch is reasonable to test. If it is, they should reply with \`/ok-to-test\` on its own line. Until that is done, I will not automatically approve the workflow runs of this PR.

Once the patch is verified, the new status will be reflected by the \`ok-to-test\` label, and the workflow runs waiting for approval — including those for future commits — will be approved automatically.
${DETAILS:-}"
