# hold

Blocks and unblocks merging with the `do-not-merge/hold` label.

## Commands

| Command        | Example       | Description                                                                                   |
| -------------- | ------------- | --------------------------------------------------------------------------------------------- |
| `/hold`        | `/hold`       | Applies the `do-not-merge/hold` label, blocking [`/merge`](../merge/README.md) and auto-merge. |
| `/hold cancel` | `/hold cancel`| Removes the `do-not-merge/hold` label.                                                        |

## Behavior

- Only available on pull requests.
- Any label starting with `do-not-merge/` blocks both `/merge` and auto-merge while present.
- After `/hold cancel`, the bot re-checks whether the PR now qualifies for [auto-merge](../merge/README.md#auto-merge).
- The label is created automatically if it does not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
