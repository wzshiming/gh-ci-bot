# check-dco

Enforces a DCO signoff on every commit of a pull request, mirroring prow's [`dco`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/dco) plugin.

## Commands

| Command      | Example      | Description                              |
| ------------ | ------------ | ---------------------------------------- |
| `/check-dco` | `/check-dco` | Re-runs the DCO signoff check of the PR. |

The command only works when `DCO_REQUIRED` is set; otherwise it replies that the check is not enabled.

## Automatic behavior

When the `DCO_REQUIRED` environment variable is set to a non-empty value (it is unset by default), the bot checks the commits of a PR whenever it is opened or pushed to:

- Every commit message must contain a line starting with `Signed-off-by:` (case-insensitive), as produced by `git commit --signoff`. Merge commits are exempt.
- When every commit is signed off, the `dco-signoff: yes` label is applied.
- When commits are missing a signoff, the `dco-signoff: no` label is applied instead, blocking [`/merge`](../merge/README.md) and auto-merge until it is resolved, and the bot comments with the list of offending commits and instructions for signing them off. The comment is replaced on every re-check and deleted once every commit is signed off.

The labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).

## Configuration

| Environment variable | Description                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| `DCO_REQUIRED`       | Set to a non-empty value to enforce a DCO signoff on PR commits. Unset (the default) to disable. |
