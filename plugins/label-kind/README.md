# label-kind

Applies or removes `kind/*` labels on a PR or issue.

## Commands

| Command              | Example                                  | Description                                          |
| -------------------- | ---------------------------------------- | ----------------------------------------------------- |
| `/kind [...]`        | `/kind bug`</br>`/kind bug,feature`      | Applies the `kind/*` labels to a PR or issue.        |
| `/remove-kind [...]` | `/remove-kind bug`                       | Removes the `kind/*` labels from a PR or issue.      |

## Behavior

- Each value is prefixed with `kind/`: `/kind bug` applies the `kind/bug` label. Multiple values can be given, separated by spaces or commas.
- The well-known prow kinds (`api-change`, `bug`, `cleanup`, `deprecation`, `documentation`, `failing-test`, `feature`, `flake`, `regression`, `support`) are created automatically if missing; other `kind/*` labels must already exist in the repository or be allowlisted via the `LABELS` environment variable (see [automatic label creation](../label/README.md#automatic-label-creation)).
- By default, the [require-matching-label](../require-matching-label/README.md) behavior adds a `needs-kind` label until a `kind/*` label is applied.
