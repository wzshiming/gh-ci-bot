#!/usr/bin/env bash

# cherry-pick plugin: picks what the merge left on the base branch (merge
# commit with -m 1, every commit of a rebase merge, the squash commit),
# reports clone and push failures instead of hiding them behind sed's status,
# and explains a push refused for a workflow file under the default token.
# git is the mock in test/mock, driven by the MOCK_GIT_* variables it documents.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

CHERRY_PICK="${PLUGINS_DIR}/cherry-pick/cherry-pick.plugin.sh"
SHA="abc1234"
CREATE_PR="gh pr create -R wzshiming/example --base release-1.0 --head cherry-pick/1/release-1.0 --title [release-1.0] Fix the fonts --body Cherry-pick of #1 to \`release-1.0\`."

begin_case "refuses to cherry-pick a PR that is not merged"
mkmerged OPEN "${SHA}" "Fix the fonts"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] The PR must be merged before cherry-picking. Please merge the PR first."
log_lacks "git clone"

begin_case "picks a merge commit with -m 1 and opens the PR"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
run "${CHERRY_PICK}" release-1.0
assert_status 0
assert_out_has "Merge commit: cherry-picking ${SHA} with -m 1"
log_has "git clone https://x-access-token:mock-token@github.com/wzshiming/example.git"
log_has "--branch release-1.0"
log_lacks "git config --global"
log_has_line "git checkout -b cherry-pick/1/release-1.0"
log_has_line "git cherry-pick -m 1 ${SHA}"
log_has_line "git push origin cherry-pick/1/release-1.0"
log_has_line "${CREATE_PR}"
log_lacks "/pulls/1/commits"
log_lacks "git diff"

begin_case "picks the merge commit alone when the PR has a single commit"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
mkcommits "1:msg a"
run "${CHERRY_PICK}" release-1.0
assert_status 0
log_has_line "gh api --paginate /repos/wzshiming/example/pulls/1/commits"
log_has_line "git cherry-pick ${SHA}"
log_lacks "git log"
log_lacks "-m 1"
log_has_line "${CREATE_PR}"

begin_case "picks every rebased commit of a rebase merge"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
export MOCK_GIT_LOG="$(printf '%s\n' "${SHA}~2=msg a" "${SHA}~1=msg b" "${SHA}~0=msg c")"
mkcommits "1:msg a" "1:msg b" "1:msg c"
run "${CHERRY_PICK}" release-1.0
assert_status 0
assert_out_has "Rebase merge: cherry-picking 3 commits up to ${SHA}"
log_has_line "git log -1 --format=%B ${SHA}~2"
log_has_line "git log -1 --format=%B ${SHA}~1"
log_has_line "git log -1 --format=%B ${SHA}~0"
log_has_line "git cherry-pick ${SHA}~3..${SHA}"
log_has_line "${CREATE_PR}"

begin_case "picks the squash commit alone when the PR's commits were squashed"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
# Only the middle message differs: every commit has to match to count as a rebase.
export MOCK_GIT_LOG="$(printf '%s\n' "${SHA}~2=msg a" "${SHA}~1=other" "${SHA}~0=msg c")"
mkcommits "1:msg a" "1:msg b" "1:msg c"
run "${CHERRY_PICK}" release-1.0
assert_status 0
assert_out_has "Squash merge or single commit: cherry-picking ${SHA}"
log_has_line "git cherry-pick ${SHA}"
log_lacks "..${SHA}"
log_has_line "${CREATE_PR}"

begin_case "reports a failed clone with the token masked"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_CLONE_FAIL=128
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to clone the repository or branch \`release-1.0\` does not exist."
assert_out_has "x-access-token:***@github.com"
assert_out_lacks "mock-token"
assert_out_lacks "Cherry-pick failed"
log_lacks "git cherry-pick"
log_lacks "git push"
log_lacks "gh pr create"

begin_case "reports a failed push and does not open a PR"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
export MOCK_GIT_PUSH_FAIL=1
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to push the cherry-pick branch: fatal: unable to access 'https://x-access-token:***@github.com/wzshiming/example.git/'"
assert_out_has "x-access-token:***@github.com"
assert_out_lacks "mock-token"
assert_out_lacks "workflows"
log_has_line "git push origin cherry-pick/1/release-1.0"
log_has_line "git diff --name-only origin/release-1.0 HEAD"
log_lacks "gh pr create"

begin_case "explains a push refused for a workflow file under the default token"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
export MOCK_GIT_PUSH_FAIL=1
export MOCK_GIT_DIFF=$'.github/workflows/ci-bot.yml\nexamples/ci-bot.yml'
export BOT_LOGIN="github-actions[bot]"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to push the cherry-pick branch: fatal:"
assert_out_has "[FAIL] This change touches \`.github/workflows/ci-bot.yml\`, which the default \`GITHUB_TOKEN\` cannot merge or push"
log_has_line "git diff --name-only origin/release-1.0 HEAD"
log_lacks "gh pr create"

begin_case "does not blame the workflows permission when no workflow file changed"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
export MOCK_GIT_PUSH_FAIL=1
export MOCK_GIT_DIFF="README.md"
export BOT_LOGIN="github-actions[bot]"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to push the cherry-pick branch:"
assert_out_lacks "workflows\` permission"

begin_case "does not blame the workflows permission for a token that is not GITHUB_TOKEN"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
export MOCK_GIT_PUSH_FAIL=1
export MOCK_GIT_DIFF=".github/workflows/ci-bot.yml"
export BOT_LOGIN="my-app[bot]"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to push the cherry-pick branch:"
assert_out_lacks "workflows\` permission"

begin_case "reports a conflicting cherry-pick and does not push"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1 p2"
export MOCK_GIT_PICK_FAIL=1
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Cherry-pick failed due to conflicts. Please cherry-pick manually."
log_has_line "git cherry-pick -m 1 ${SHA}"
log_lacks "git push"
log_lacks "gh pr create"

begin_case "refuses a PR whose commit list may be truncated at 250"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
commits=()
for ((i = 1; i <= 250; i++)); do
    commits+=("1:commit ${i}")
done
mkcommits "${commits[@]}"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] The pull request has too many commits to cherry-pick automatically. Please cherry-pick manually."
log_lacks "git cherry-pick"
log_lacks "gh pr create"

begin_case "fails closed when the commit list comes back empty"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
mkcommits
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to get the commits of the pull request."
log_lacks "git cherry-pick"
log_lacks "gh pr create"

begin_case "fails closed when the commit list has no messages"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
echo '[{}]' >"${MOCK_PR_COMMITS_JSON}"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to get the commits of the pull request."
log_lacks "git cherry-pick"

begin_case "fails closed when the pull request cannot be fetched"
export MOCK_GH_FAIL=1
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Failed to get the pull request."
log_lacks "git clone"

begin_case "refuses a merged PR without a merge commit"
mkmerged MERGED "" "Fix the fonts"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Could not find the merge commit for this PR."
log_lacks "git clone"

begin_case "flattens the paginated commit list before comparing messages"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
export MOCK_GIT_LOG="$(printf '%s\n' "${SHA}~2=msg a" "${SHA}~1=msg b" "${SHA}~0=msg c")"
# gh api --paginate prints one array per page.
mkcommits "1:msg a" "1:msg b"
jq -n '[{sha: "sha-3", parents: [{sha: "parent-0"}], commit: {message: "msg c"}}]' >>"${MOCK_PR_COMMITS_JSON}"
run "${CHERRY_PICK}" release-1.0
assert_status 0
assert_out_has "Rebase merge: cherry-picking 3 commits up to ${SHA}"
log_has_line "git cherry-pick ${SHA}~3..${SHA}"

begin_case "fails closed when the history before the merge commit cannot be read"
mkmerged MERGED "${SHA}" "Fix the fonts"
export MOCK_GIT_PARENTS="${SHA} p1"
export MOCK_GIT_LOG_FAIL=128
mkcommits "1:msg a" "1:msg b"
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "[FAIL] Could not read the commits before ${SHA} in the repository."
log_lacks "git cherry-pick"
log_lacks "gh pr create"

begin_case "masks a token containing regex metacharacters literally"
mkmerged MERGED "${SHA}" "Fix the fonts"
export GH_TOKEN='se.ret$tok'
export MOCK_GIT_CLONE_FAIL=128
run "${CHERRY_PICK}" release-1.0
assert_status 1
assert_out_has "x-access-token:***@github.com"
assert_out_lacks 'se.ret$tok'
