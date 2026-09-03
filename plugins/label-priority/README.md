# label-priority

Applies or removes `priority/*` labels on a PR or issue.

## Commands

| Command                  | Example                                                 | Description                                            |
| ------------------------ | ------------------------------------------------------- | ------------------------------------------------------- |
| `/priority [...]`        | `/priority backlog`</br>`/priority backlog,critical-urgent` | Applies the `priority/*` labels to a PR or issue.  |
| `/remove-priority [...]` | `/remove-priority backlog`                              | Removes the `priority/*` labels from a PR or issue.    |

## Behavior

- Each value is prefixed with `priority/`: `/priority backlog` applies the `priority/backlog` label. Multiple values can be given, separated by spaces or commas.
- The well-known prow priorities (`awaiting-more-evidence`, `backlog`, `critical-urgent`, `important-longterm`, `important-soon`) are created automatically if missing; other `priority/*` labels must already exist in the repository or be allowlisted via the `LABELS` environment variable (see [automatic label creation](../label/README.md#automatic-label-creation)).
