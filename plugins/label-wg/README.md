# label-wg

Applies or removes `wg/*` (working group) labels on a PR or issue.

## Commands

| Command            | Example                              | Description                                     |
| ------------------ | ------------------------------------ | ------------------------------------------------ |
| `/wg [...]`        | `/wg policy`</br>`/wg policy,docs`   | Applies the `wg/*` labels to a PR or issue.     |
| `/remove-wg [...]` | `/remove-wg policy`                  | Removes the `wg/*` labels from a PR or issue.   |

## Behavior

- Each value is prefixed with `wg/`: `/wg policy` applies the `wg/policy` label. Multiple values can be given, separated by spaces or commas.
- `wg/*` labels are repository-specific, so they must already exist in the repository or be allowlisted via the `LABELS` environment variable (e.g. a `wg/` entry) to be created automatically (see [automatic label creation](../label/README.md#automatic-label-creation)).
