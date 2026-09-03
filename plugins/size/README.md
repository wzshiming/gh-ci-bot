# size

Automatic behavior with no commands: labels every PR with a `size/*` label, mirroring prow's [`size`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/size) plugin.

## Behavior

Every PR is labeled with exactly one of the size labels based on the total number of changed lines (additions + deletions), updating the label whenever new commits are pushed. The thresholds mirror prow's defaults:

| Label      | Changed lines |
| ---------- | ------------- |
| `size/XS`  | < 10          |
| `size/S`   | < 30          |
| `size/M`   | < 100         |
| `size/L`   | < 500         |
| `size/XL`  | < 1000        |
| `size/XXL` | ≥ 1000        |

The labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
