# cc

Requests or removes review requests on a pull request.

## Commands

| Command            | Example                                | Description                                                                                          |
| ------------------ | -------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `/cc [[@]...]`     | `/cc`</br>`/cc @wzshiming`             | Requests a review from the user(s). Without arguments, requests a review from the commenter.         |
| `/uncc [[@]...]`   | `/uncc`</br>`/uncc @wzshiming`         | Removes the review request(s). Without arguments, removes the commenter's review request.            |

## Behavior

- Only available on pull requests.
- Multiple users can be given in one command, separated by spaces; the leading `@` is optional.
- GitHub only accepts review requests for users with access to the repository, so the requested user must be a member or collaborator.

To have reviewers picked automatically from OWNERS files, see the [auto-cc](../auto-cc/README.md) command and the [blunderbuss](../../README.md#auto-requesting-reviewers) behavior.
