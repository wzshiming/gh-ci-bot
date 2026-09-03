# blunderbuss

Automatic behavior with no commands: requests reviewers when a PR is opened, mirroring prow's [`blunderbuss`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/blunderbuss) plugin. It is the automatic counterpart of the [`/auto-cc`](../auto-cc/README.md) command; both share the same reviewer-selection logic.

## Behavior

- Runs when a PR is opened; draft PRs are skipped.
- Every changed file is mapped to the nearest ancestor directory whose [OWNERS file](../../README.md#owners-files) lists at least one reviewer. Reviewers are picked round-robin across those directories (randomly within each), so every changed area gets a reviewer before any area gets a second one.
- If not enough reviewers are found in OWNERS files, the remainder is filled randomly from the `REVIEWERS` environment variable.
- The PR author is never picked.

## Configuration

| Environment variable         | Description                                                                                                                       |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `BLUNDERBUSS_REVIEWER_COUNT` | Number of reviewers to request (default `2`). Set to `0` to disable the automatic behavior (the manual `/auto-cc` command keeps working). |
