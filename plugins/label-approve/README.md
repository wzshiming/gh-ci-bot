# label-approve

Approves the PR areas the commenter owns via [OWNERS files](../../README.md#owners-files), mirroring prow's [`approve`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/approve) plugin.

## Commands

| Command           | Example           | Description                                                       |
| ----------------- | ----------------- | ------------------------------------------------------------------ |
| `/approve`        | `/approve`        | Approves the PR areas the commenter owns (via OWNERS files).       |
| `/approve cancel` | `/approve cancel` | Revokes the commenter's approval.                                  |
| `/remove-approve` | `/remove-approve` | Revokes the commenter's approval.                                  |

## Behavior

- Only available on pull requests.
- Every changed file is mapped to its *area* (the nearest ancestor directory whose OWNERS file lists at least one approver, falling back to the repository root); `/approve` approves the areas whose approver list contains the commenter. See [Hierarchical OWNERS](../../README.md#hierarchical-owners).
- The `approved` label is added once all areas are covered, and removed when they no longer are.
- Approvals are sticky across new commits, mirroring prow's approve plugin, and are recomputed against the current change set on every push.
- Areas owned by the PR author are approved by default (implicit self-approval); the author may still `/approve` explicitly.
- The per-area approval state is kept in a single bot comment with a human-readable summary table.
- Once the PR has both `approved` and `lgtm` (see [label-lgtm](../label-lgtm/README.md)), it is [auto-merged](../merge/README.md#auto-merge).
