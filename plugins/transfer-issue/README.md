# transfer-issue

Transfers an issue to another repository in the same organization.

## Commands

| Command                  | Example                      | Description                                                          |
| ------------------------ | ---------------------------- | -------------------------------------------------------------------- |
| `/transfer-issue <repo>` | `/transfer-issue other-repo` | Transfers an issue to another repository in the same organization.   |
| `/transfer <repo>`       | `/transfer other-repo`       | Prow-style alias of `/transfer-issue`.                               |

## Behavior

- Only available on issues, not on pull requests.
- The target repository can be given as `repo` or `org/repo`, but must belong to the same organization (or user) as the current repository, must exist and must be accessible.
