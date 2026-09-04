# rebase

Rebases a pull request onto the latest base branch.

## Commands

| Command   | Example   | Description                                     |
| --------- | --------- | ----------------------------------------------- |
| `/rebase` | `/rebase` | Rebases the PR onto the latest base branch.     |

## Behavior

- Only available on pull requests.
- Fails with a reply when the branch cannot be rebased cleanly; conflicts need to be resolved manually.
- When the bot runs with the default `GITHUB_TOKEN`, its push starts no workflow runs, so after the rebase it starts its own `synchronize` run (lgtm removed, labels re-synced) and the `DISPATCH_WORKFLOWS` on the PR's branch; for a PR from a fork only the bot's run can be started and the reply says so. A PAT or GitHub App token fires the real `synchronize` event instead. See [Dispatched workflows](../../README.md#dispatched-workflows).
