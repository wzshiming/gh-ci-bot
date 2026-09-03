# wip

Automatic behavior with no commands: keeps the `do-not-merge/work-in-progress` label in sync with the PR's draft state and title, mirroring prow's [`wip`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/wip) plugin.

## Behavior

- The label is applied while the PR is a draft or its title starts with `WIP` (case-insensitive; leading spaces or punctuation are ignored, so `[WIP] Title` and `WIP: Title` also match), and removed once neither is true.
- Any label starting with `do-not-merge/` blocks both [`/merge`](../merge/README.md) and auto-merge while present.
- The label is synced whenever the PR is opened, pushed to, edited, or its draft state changes, and immediately after a [`/retitle`](../retitle/README.md).
- The label is created automatically if it does not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
