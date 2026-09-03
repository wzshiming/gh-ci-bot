# label-sig

Applies or removes `sig/*` (special interest group) labels on a PR or issue.

## Commands

| Command             | Example                            | Description                                       |
| ------------------- | ---------------------------------- | -------------------------------------------------- |
| `/sig [...]`        | `/sig node`</br>`/sig node,api`    | Applies the `sig/*` labels to a PR or issue.      |
| `/remove-sig [...]` | `/remove-sig node`                 | Removes the `sig/*` labels from a PR or issue.    |

## Behavior

- Each value is prefixed with `sig/`: `/sig node` applies the `sig/node` label. Multiple values can be given, separated by spaces or commas.
- `sig/*` labels are repository-specific, so they must already exist in the repository or be allowlisted via the `LABELS` environment variable (e.g. a `sig/` entry) to be created automatically (see [automatic label creation](../label/README.md#automatic-label-creation)).
