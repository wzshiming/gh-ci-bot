# merge

Merges a pull request.

## Commands

| Command                   | Example                                          | Description                                                  |
| ------------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `/merge [rebase\|squash]` | `/merge`</br>`/merge rebase`</br>`/merge squash` | Merges the PR, optionally overriding the merge method.       |

## Behavior

- Only available on pull requests.
- Without an argument, the merge method comes from the `DEFAULT_MERGE_METHOD` environment variable (`merge`, `rebase` or `squash`; default `merge`).
- Merging is refused while the PR carries any `do-not-merge/*` label (e.g. from [hold](../hold/README.md), [wip](../../README.md#work-in-progress), [release-note](../release-note/README.md) or [require-matching-label](../../README.md#require-matching-label)); the blocking labels are listed in the reply.
- If a direct merge fails (for example because required checks are still pending), the bot falls back to enabling GitHub auto-merge so the PR merges once they pass.

## Auto-merge

Like [tide](https://docs.prow.k8s.io/docs/components/core/tide/), the bot maintains a merge pool: the open PRs carrying both the `lgtm` ([label-lgtm](../label-lgtm/README.md)) and `approved` ([label-approve](../label-approve/README.md)) labels. A pool PR is merged automatically (with the default merge method) only after the bot re-validates its state right before merging:

- the `lgtm` and `approved` labels are re-fetched and still present, and no `do-not-merge/*` label is present;
- every changed area from the [OWNERS files](../../README.md#owners-files) is approved;
- the PR has no conflicts with the base branch (and GitHub has finished computing its mergeability);
- the PR head is up to date with the base branch, so its checks ran against the latest base;
- every check on the PR head is green (the bot's own workflow run is excluded, since it is still in progress while it evaluates the merge). Pending or failing checks skip the merge instead of scheduling GitHub auto-merge, because a merge scheduled ahead of time would bypass this re-validation.

The bot evaluates this at the end of every PR event, and the scheduled merge pool sync (see the `schedule` trigger in [examples/ci-bot.yml](../../examples/ci-bot.yml)) re-evaluates the whole pool periodically, oldest PR first, one at a time. Merges are therefore serialized: each merge makes the remaining pool PRs stale, so they are refreshed and retested against the new base before they can merge, avoiding semantic conflicts between independently-green PRs.

When a pool PR falls behind the base branch it is skipped; set `AUTO_MERGE_UPDATE_BRANCH` to make the bot update the branch with the latest base so the checks rerun (tide's retest). The push keeps the `lgtm` label (only pushes by someone other than the bot invalidate it), and requires `GH_TOKEN` to be a PAT or GitHub App token, because pushes made with the default `GITHUB_TOKEN` do not trigger workflows.

## Configuration

| Environment variable       | Description                                                       |
| -------------------------- | ----------------------------------------------------------------- |
| `DEFAULT_MERGE_METHOD`     | Default merge method: `merge`, `rebase` or `squash`. Default: `merge`. |
| `AUTO_MERGE_UPDATE_BRANCH` | When non-empty, auto-merge updates stale pool PRs with the latest base branch to retest them. Requires a PAT or GitHub App token. Default: unset. |
