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
- [Auto-merge](../merge/README.md#auto-merge) is evaluated at the end of every PR event, so a PR that qualifies is merged as soon as the hold is removed, whether by `/hold cancel` or from the UI.
- The label is created automatically if it does not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
