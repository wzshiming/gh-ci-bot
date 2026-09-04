# cherry-pick-approved

Approves a PR into a release branch, lifting the merge gate applied when `RELEASE_BRANCHES` is set.

## Commands

| Command                        | Example                        | Description                                                                                                                          |
| ------------------------------ | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `/cherry-pick-approved`        | `/cherry-pick-approved`        | Applies the `cherry-pick-approved` label and removes `do-not-merge/cherry-pick-not-approved`, unblocking a PR into a release branch. |
| `/cherry-pick-approved cancel` | `/cherry-pick-approved cancel` | Removes the `cherry-pick-approved` label.                                                                                            |

## Behavior

- Only available on pull requests.
- Like prow's [`cherrypickunapproved`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/cherrypickunapproved) plugin, when the `RELEASE_BRANCHES` environment variable is set to a regular expression (it is unset by default), every PR whose base branch matches it carries the `do-not-merge/cherry-pick-not-approved` label until it has `cherry-pick-approved`, blocking [`/merge`](../merge/README.md) and auto-merge. `/cherry-pick-approved cancel` removes `cherry-pick-approved`, and the blocking label comes back.
- The labels are synced on every PR event, so retargeting the PR to a branch that does not match (e.g. with [`/base`](../base/README.md)) removes both labels. Labels only, no comments.
- Approving a cherry-pick is a release-branch decision, so this plugin belongs to a higher tier than [`/cherry-pick`](../cherry-pick/README.md): the example workflow lists it under `MAINTAINERS_PLUGINS`.
- Both labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
