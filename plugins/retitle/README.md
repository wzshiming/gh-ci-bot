# retitle

Edits the title of a PR or issue.

## Commands

| Command            | Example              | Description                     |
| ------------------ | -------------------- | ------------------------------- |
| `/retitle <title>` | `/retitle New Title` | Edits the PR or issue title.    |

## Behavior

- Everything after `/retitle` becomes the new title.
- On pull requests, the [work-in-progress](../../README.md#work-in-progress) label is synced right away, since title edits made with `GITHUB_TOKEN` do not trigger workflows.
