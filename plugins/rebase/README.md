# rebase

Rebases a pull request onto the latest base branch.

## Commands

| Command   | Example   | Description                                     |
| --------- | --------- | ----------------------------------------------- |
| `/rebase` | `/rebase` | Rebases the PR onto the latest base branch.     |

## Behavior

- Only available on pull requests.
- Fails with a reply when the branch cannot be rebased cleanly; conflicts need to be resolved manually.
