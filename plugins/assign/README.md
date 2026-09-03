# assign

Assigns or unassigns users on a PR or issue.

## Commands

| Command                | Example                                            | Description                                                                                 |
| ---------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `/assign [[@]...]`     | `/assign`</br>`/assign @wzshiming`                 | Assigns the user(s) to the PR or issue. Without arguments, assigns the commenter.           |
| `/unassign [[@]...]`   | `/unassign`</br>`/unassign @wzshiming`             | Removes the assignee(s) from the PR or issue. Without arguments, unassigns the commenter.   |

## Behavior

- Multiple users can be given in one command, separated by spaces; the leading `@` is optional.
- Assigning fails for users who cannot be assigned in the repository (e.g. unknown usernames); the bot replies with the failing user(s).
