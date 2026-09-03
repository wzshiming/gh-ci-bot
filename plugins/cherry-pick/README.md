# cherry-pick

Cherry-picks a merged pull request to a target branch and creates a new PR.

## Commands

| Command                 | Example                    | Description                                                         |
| ----------------------- | -------------------------- | ------------------------------------------------------------------- |
| `/cherry-pick <branch>` | `/cherry-pick release-1.0` | Cherry-picks a merged PR to a target branch and creates a new PR.   |

## Behavior

- Only available on pull requests, and only after the PR has been **merged**.
- The PR's merge commit is cherry-picked onto a new branch named `cherry-pick-<pr-number>-to-<branch>`, which is pushed to the repository.
- A new PR titled `[<branch>] <original title>` is opened against the target branch, with a body referencing the original PR.
- If the cherry-pick has conflicts, the command fails with a reply and the cherry-pick needs to be done manually.

## Troubleshooting

If you encounter the error `pull request create failed: GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)`, go to your repository settings under the Actions section and check `Allow GitHub Actions to create and approve pull requests`.
