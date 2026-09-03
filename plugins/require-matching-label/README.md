# require-matching-label

Automatic behavior with no commands: applies a `needs-X` label when an issue or PR is missing a label matching a configured regular expression, and removes it once a matching label is added, mirroring prow's [`require-matching-label`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/require-matching-label) plugin.

## Behavior

- By default, an issue or PR without a `kind/*` label gets the `needs-kind` label, which is removed as soon as a `kind/*` label is applied (e.g. via [`/kind bug`](../label-kind/README.md)).
- The labels are synced whenever the issue or PR is opened, commented on, labeled or unlabeled.
- Using a `do-not-merge/*` missing label (e.g. `do-not-merge/needs-kind` for PRs) additionally blocks [`/merge`](../merge/README.md) and auto-merge until a matching label is added.
- The missing labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).

## Configuration

The rules are configured through the `ISSUE_REQUIRE_MATCHING_LABELS` (issues) and `PR_REQUIRE_MATCHING_LABELS` (PRs) environment variables, one rule per line in the format `<missing-label> <regexp>`:

```yaml
env:
  ISSUE_REQUIRE_MATCHING_LABELS: |-
    needs-kind ^kind/
  PR_REQUIRE_MATCHING_LABELS: |-
    do-not-merge/needs-kind ^kind/
    needs-priority ^priority/
```

When a variable is unset, it defaults to `needs-kind ^kind/`. Set a variable to an empty string to disable the check for the corresponding scope.
