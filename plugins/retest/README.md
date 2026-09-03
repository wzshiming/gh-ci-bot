# retest

Reruns GitHub Actions workflows or jobs for a pull request.

## Commands

| Command                        | Example                                          | Description                                                                     |
| ------------------------------ | ------------------------------------------------ | ------------------------------------------------------------------------------- |
| `/retest`                      | `/retest`                                        | Reruns the failed jobs of all failed workflow runs of the PR.                   |
| `/test [workflow-or-job\|all]` | `/test all`</br>`/test CI`</br>`/test unit-test` | Reruns a specific workflow or job for the PR by name, or all of them with `all`. |

## Behavior

- Only available on pull requests. Runs are looked up for the PR's current head commit.
- `/retest` only reruns the *failed* jobs of failed workflow runs, like clicking "Re-run failed jobs".
- `/test <name>` first tries to match a workflow by its display name or workflow file name (e.g. `CI` or `ci.yaml`); if nothing matches, it falls back to matching a job by name inside the PR's workflow runs.
- When the target cannot be found, the reply lists the workflows available for the PR.
