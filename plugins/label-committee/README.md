# label-committee

Applies or removes `committee/*` labels on a PR or issue.

## Commands

| Command                   | Example                                                | Description                                             |
| ------------------------- | ------------------------------------------------------ | -------------------------------------------------------- |
| `/committee [...]`        | `/committee steering`</br>`/committee steering,conduct` | Applies the `committee/*` labels to a PR or issue.     |
| `/remove-committee [...]` | `/remove-committee steering`                           | Removes the `committee/*` labels from a PR or issue.    |

## Behavior

- Each value is prefixed with `committee/`: `/committee steering` applies the `committee/steering` label. Multiple values can be given, separated by spaces or commas.
- `committee/*` labels are repository-specific, so they must already exist in the repository or be allowlisted via the `LABELS` environment variable (e.g. a `committee/` entry) to be created automatically (see [automatic label creation](../label/README.md#automatic-label-creation)).
