# label-lgtm

Applies or removes the `lgtm` ("looks good to me") label on a pull request.

## Commands

| Command        | Example        | Description                        |
| -------------- | -------------- | ---------------------------------- |
| `/lgtm`        | `/lgtm`        | Applies the `lgtm` label.          |
| `/remove-lgtm` | `/remove-lgtm` | Removes the `lgtm` label.          |

## Behavior

- Only available on pull requests.
- You cannot `/lgtm` your own PR.
- The label is removed automatically whenever new commits are pushed to the PR.
- Once the PR has both `lgtm` and `approved` (see [label-approve](../label-approve/README.md)), it is [auto-merged](../merge/README.md#auto-merge).
- The label is created automatically if it does not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).
