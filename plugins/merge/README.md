# merge

Merges a pull request.

## Commands

| Command                   | Example                                          | Description                                                  |
| ------------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `/merge [rebase\|squash]` | `/merge`</br>`/merge rebase`</br>`/merge squash` | Merges the PR, optionally overriding the merge method.       |

## Behavior

- Only available on pull requests.
- Without an argument, the merge method comes from the `DEFAULT_MERGE_METHOD` environment variable (`merge`, `rebase` or `squash`; default `merge`).
- Merging is refused while the PR carries the `do-not-merge` label or any `do-not-merge/*` label (e.g. from [hold](../hold/README.md), [wip](../../README.md#work-in-progress), [release-note](../release-note/README.md) or [require-matching-label](../../README.md#require-matching-label)) or the `dco-signoff: no` label ([check-dco](../check-dco/README.md)); the blocking labels are listed in the reply.
- If a direct merge fails (for example because required checks are still pending), the bot falls back to enabling GitHub auto-merge so the PR merges once they pass.

## Auto-merge

A PR is merged automatically (with the default merge method) once it has both the `lgtm` ([label-lgtm](../label-lgtm/README.md)) and `approved` ([label-approve](../label-approve/README.md)) labels, every changed area is approved, and no `do-not-merge`, `do-not-merge/*` or `dco-signoff: no` label is present. The bot evaluates this once at the end of every PR event, so the merge happens no matter which command, label sync or UI action removed the last blocker.

## Configuration

| Environment variable   | Description                                                       |
| ---------------------- | ----------------------------------------------------------------- |
| `DEFAULT_MERGE_METHOD` | Default merge method: `merge`, `rebase` or `squash`. Default: `merge`. |
