# cherry-pick

Cherry-picks a merged pull request to a target branch and creates a new PR.

## Commands

| Command                        | Example                        | Description                                                                                                                          |
| ------------------------------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `/cherry-pick <branch>`        | `/cherry-pick release-1.0`     | Cherry-picks a merged PR to a target branch and creates a new PR.                                                                    |
| `/cherry-pick-approved`        | `/cherry-pick-approved`        | Applies the `cherry-pick-approved` label and removes `do-not-merge/cherry-pick-not-approved`, unblocking a PR into a release branch. |
| `/cherry-pick-approved cancel` | `/cherry-pick-approved cancel` | Removes the `cherry-pick-approved` label.                                                                                            |

## Behavior

- `/cherry-pick` is only available on pull requests, and only after the PR has been **merged**.
- The PR's merge commit is cherry-picked (with `-m 1` if it is a merge commit) onto a new branch named `cherry-pick/<pr-number>/<branch>`, which is pushed to the repository. For a PR merged with the rebase method, all of the PR's rebased commits are cherry-picked.
- A new PR titled `[<branch>] <original title>` is opened against the target branch, with a body referencing the original PR.
- If the clone or the push fails, the command fails with a reply quoting git's error. If the cherry-pick has conflicts, the command fails with a reply and the cherry-pick needs to be done manually.
- If the push is refused because the cherry-pick changes a file under `.github/workflows/` and the bot runs with the default `GITHUB_TOKEN`, the reply also names the workflow files and explains that the token cannot be granted the `workflows` permission.

## Cherry-pick approval

Like prow's [`cherrypickunapproved`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/cherrypickunapproved) plugin, when the `RELEASE_BRANCHES` environment variable is set to a regular expression (it is unset by default), every PR whose base branch matches it carries the `do-not-merge/cherry-pick-not-approved` label until it has `cherry-pick-approved`. `/cherry-pick-approved` (only available on pull requests, meant for approvers) applies `cherry-pick-approved` and removes the blocking label; `/cherry-pick-approved cancel` removes `cherry-pick-approved`, and the blocking label comes back. The labels are synced on every PR event, so retargeting the PR to a branch that does not match (e.g. with [`/base`](../base/README.md)) removes both labels. Labels only, no comments; both labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).

## Troubleshooting

If you encounter the error `pull request create failed: GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)`, go to your repository settings under the Actions section and check `Allow GitHub Actions to create and approve pull requests`.

If the push is rejected with `refusing to allow a GitHub App to create or update workflow ... without workflows permission`, see [Changes to `.github/workflows/**`](../../README.md#troubleshooting) in the main README.
