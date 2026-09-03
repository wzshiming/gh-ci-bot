#!/usr/bin/env bash

# Sync the dco-signoff labels on a PR, mirroring prow's dco plugin: every
# commit of the PR must carry a line starting with "Signed-off-by:"
# (case-insensitive, as produced by git commit --signoff); merge commits
# are exempt. A PR whose commits are all signed off gets the
# "dco-signoff: yes" label; otherwise "dco-signoff: no" is applied, which
# blocks /merge and auto-merge, and the bot comments with the list of
# commits missing a signoff and instructions to fix them. The comment is
# replaced on every re-check and deleted once every commit is signed off.
#
# Opt-in: does nothing unless the DCO_REQUIRED environment variable is
# set to a non-empty value.

if [[ "${ISSUE_KIND}" != "pr" ]]; then
    return 0 2>/dev/null || exit 0
fi

if [[ -z "${DCO_REQUIRED:-}" ]]; then
    return 0 2>/dev/null || exit 0
fi

DCO_YES_LABEL="dco-signoff: yes"
DCO_NO_LABEL="dco-signoff: no"
# The first line of the bot's comment, also used to find and delete stale
# comments; keep it in sync with the comment body below.
DCO_MSG_MARKER="Thanks for your pull request. Before we can look at it, you'll need to add a 'DCO signoff' to your commits."

if ! commits="$(gh api --paginate "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/commits")"; then
    # Never mutate labels from missing commit data.
    echo "Failed to get the pull request commits, skipping the DCO sync."
    return 0 2>/dev/null || exit 0
fi

# The markdown list of commits missing a signoff: every non-merge commit
# whose message has no line starting with "Signed-off-by:", like prow's
# (?mi)^signed-off-by: check.
missing="$(echo "${commits}" | jq -r '
    .[]
    | select((.parents | length) < 2)
    | select(any(.commit.message // "" | split("\n")[]; test("^signed-off-by:"; "i")) | not)
    | "- [" + .sha[0:7] + "](" + .html_url + ") " + (.commit.message // "" | split("\n")[0])')"

if ! labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '.labels[].name')"; then
    echo "Failed to get the pull request labels, skipping the DCO sync."
    return 0 2>/dev/null || exit 0
fi

# prune_dco_comments deletes the bot's previous DCO comments, so the PR
# never carries a stale list of unsigned commits.
function prune_dco_comments() {
    local bot_login ids id
    bot_login="$(bot-login.sh)"
    ids="$(gh api --paginate "/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/comments" |
        jq -r --arg login "${bot_login}" --arg marker "${DCO_MSG_MARKER}" \
            '.[] | select(.user.login == $login and (.body | contains($marker))) | .id')"
    while read -r id; do
        if [[ -n "${id}" ]]; then
            gh api --silent -X DELETE "/repos/${GH_REPOSITORY}/issues/comments/${id}"
        fi
    done <<<"${ids}"
}

if [[ -z "${missing}" ]]; then
    echo "All commits have Signed-off-by."
    if grep -qxF "${DCO_NO_LABEL}" <<<"${labels}"; then
        remove-labels.sh "${DCO_NO_LABEL}"
    fi
    if ! grep -qxF "${DCO_YES_LABEL}" <<<"${labels}"; then
        add-labels.sh "${DCO_YES_LABEL}"
    fi
    prune_dco_comments
    return 0 2>/dev/null || exit 0
fi

echo "Commits in PR missing Signed-off-by."
if ! grep -qxF "${DCO_NO_LABEL}" <<<"${labels}"; then
    add-labels.sh "${DCO_NO_LABEL}"
fi
if grep -qxF "${DCO_YES_LABEL}" <<<"${labels}"; then
    remove-labels.sh "${DCO_YES_LABEL}"
fi

# Replace any previous comment with the latest list of unsigned commits.
prune_dco_comments

server_url="${GITHUB_SERVER_URL:-https://github.com}"
branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"

comment.sh "$(cat <<EOF
${DCO_MSG_MARKER}

:memo: **Please follow instructions in the [contributing guide](${server_url%/}/${GH_REPOSITORY}/blob/${branch}/CONTRIBUTING.md) to update your commits with the DCO**

Full details of the Developer Certificate of Origin can be found at [developercertificate.org](https://developercertificate.org/).

**The list of commits missing DCO signoff**:

${missing}

<details>
<summary>Instructions for adding a signoff</summary>

Sign off the last commit and force-push:

\`\`\`console
git commit --amend --signoff
git push --force-with-lease
\`\`\`

Or sign off every commit of the branch (N is the number of commits):

\`\`\`console
git rebase --signoff HEAD~N
git push --force-with-lease
\`\`\`

</details>
EOF
)"
