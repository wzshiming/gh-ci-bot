# label-triage

Applies or removes `triage/*` labels on a PR or issue.

## Commands

| Command                | Example                                            | Description                                          |
| ---------------------- | -------------------------------------------------- | ----------------------------------------------------- |
| `/triage [...]`        | `/triage accepted`</br>`/triage accepted,duplicate` | Applies the `triage/*` labels to a PR or issue.     |
| `/remove-triage [...]` | `/remove-triage accepted`                          | Removes the `triage/*` labels from a PR or issue.    |

## Behavior

- Each value is prefixed with `triage/`: `/triage accepted` applies the `triage/accepted` label. Multiple values can be given, separated by spaces or commas.
- The well-known prow triage states (`accepted`, `duplicate`, `needs-information`, `not-reproducible`, `unresolved`) are created automatically if missing; other `triage/*` labels must already exist in the repository or be allowlisted via the `LABELS` environment variable (see [automatic label creation](../label/README.md#automatic-label-creation)).
