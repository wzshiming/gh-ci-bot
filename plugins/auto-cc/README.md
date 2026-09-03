# auto-cc

Requests reviews from automatically selected reviewers, using the same reviewer-selection logic as the automatic [blunderbuss](../../README.md#auto-requesting-reviewers) behavior that runs when a PR is opened or marked ready for review.

## Commands

| Command    | Example    | Description                                          |
| ---------- | ---------- | ---------------------------------------------------- |
| `/auto-cc` | `/auto-cc` | Requests reviews from randomly selected reviewers.   |

## Behavior

- Only available on pull requests.
- Reviewers are picked from the `OWNERS` files nearest to the changed files, falling back to the `REVIEWERS` environment variable; the PR author is never picked. See [blunderbuss](../../README.md#auto-requesting-reviewers) for the full selection logic.
- The number of reviewers to request is taken from the `BLUNDERBUSS_REVIEWER_COUNT` environment variable (default `2`). Unlike the automatic behavior, the command keeps working when the variable is `0`: it then requests 2 reviewers.
- Replies with a failure when no reviewers can be found; make sure `OWNERS` files or `REVIEWERS` are configured.
