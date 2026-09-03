# label

Applies or removes arbitrary labels on a PR or issue, and documents how the bot creates labels.

## Commands

| Command                 | Example                              | Description                                            |
| ----------------------- | ------------------------------------ | ------------------------------------------------------ |
| `/label [...]`          | `/label doc`</br>`/label doc,cli`    | Applies the '*' labels to a PR or issue.               |
| `/remove-label [...]`   | `/remove-label doc`                  | Removes the '*' labels from a PR or issue.             |

## Behavior

- Multiple labels can be given in one command, separated by spaces or commas.
- Labels that do not exist in the repository are created automatically only when they are allowlisted, see below; otherwise the command fails with a reply for that label.

## Automatic label creation

Whenever the bot adds a label (via commands like `/label`, `/kind`, `/lgtm`, `/approve`, OWNERS `labels:`, or automatic labels like `do-not-merge/work-in-progress`), any label that does not yet exist in the repository is created automatically, provided it is in the built-in default list of well-known labels (see [`bin/ensure-labels.sh`](../../bin/ensure-labels.sh)) or listed in the `LABELS` environment variable. Labels not in the allowlist are never created automatically (so a typo like `/label doocumentation` does not pollute the repository); they are only applied if they already exist in the repository.

Created labels get the well-known color and description from prow's [label definitions](https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.yaml) where available, falling back to GitHub's defaults.

## Configuration

| Environment variable | Description                                                                                                                                                                                             |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `LABELS`             | Additional labels the bot is allowed to create, one entry per line. Each entry is either an exact label name, or a prefix ending in a slash (e.g. `kind/`) which allows any label with that prefix. Entries are merged with the built-in default list. |

```yaml
env:
  LABELS: |-
    kind/docs
    area/
```
