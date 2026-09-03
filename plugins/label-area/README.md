# label-area

Applies or removes `area/*` labels on a PR or issue.

## Commands

| Command              | Example                          | Description                                        |
| -------------------- | -------------------------------- | --------------------------------------------------- |
| `/area [...]`        | `/area api`</br>`/area api,cli`  | Applies the `area/*` labels to a PR or issue.      |
| `/remove-area [...]` | `/remove-area api`               | Removes the `area/*` labels from a PR or issue.    |

## Behavior

- Each value is prefixed with `area/`: `/area api` applies the `area/api` label. Multiple values can be given, separated by spaces or commas.
- `area/*` labels are repository-specific, so they must already exist in the repository or be allowlisted via the `LABELS` environment variable (e.g. an `area/` entry) to be created automatically (see [automatic label creation](../label/README.md#automatic-label-creation)).
