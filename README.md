# gh-ci-bot

| Command                           | Example                                                                 | Description                                                                                              | Plugin                 |
| --------------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------- |
| `/retitle`                        | `/retitle New Title`                                                    | Edits the PR or issue title.                                                                             | retitle                |
| `/[un]cc [[@]...]`                | `/cc`</br>`/uncc`</br>`/cc @wzshiming`                                  | Requests a review from the user(s). Must be a Member.                                                    | cc                     |
| `/auto-cc`                        | `/auto-cc`                                                              | Requests a review from the random Reviewer.                                                              | auto-cc                |
| `/[un]assign [[@]...]`            | `/assign`</br>`/unassign`</br>`/assign @wzshiming`                      | Assigns assignee(s) to the PR or issue.                                                                  | assign                 |
| `/[remove-]milestone [milestone]` | `/milestone v1.0.0`</br>`/remove-milestone`                             | Edits the PR or issue milestone. Milestone need to be created manually in advance.                       | milestone              |
| `/close`                          | `/close`                                                                | Closes an PR or issue.                                                                                   | lifecycle              |
| `/reopen`                         | `/reopen`                                                               | Reopen an PR or issue.                                                                                   | lifecycle              |
| `/merge [rebase\|squash]`         | `/merge`</br>`/merge rebase`</br>`/merge squash`                        | Merge a PR.                                                                                              | merge                  |
| `	/[remove-]kind [kind/*...]`     | `/kind doc`</br>`/remove-kind doc`                                      | Applies or removes the 'kind/*' labels to an PR or issue. Labels need to be created manually in advance. | kind                   |
| `	/[remove-]help[-wanted]`        | `/help`</br>`/remove-help`</br>`/help-wanted`</br>`/remove-help-wanted` | Applies or removes the 'help wanted' labels to an PR or issue.                                           | label-help-wanted      |
| `	/[remove-]good-first-issue`     | `/good-first-issue`</br>`/remove-good-first-issue`                      | Applies or removes the 'good first issue' labels to an PR or issue.                                      | label-good-first-issue |
| `	/[remove-]bug`                  | `/bug`</br>`/remove-bug`                                                | Applies or removes the 'bug' labels to an PR or issue.                                                   | label-bug              |
| `	/[remove-]documentation`        | `/documentation`</br>`/remove-documentation`                            | Applies or removes the 'documentation' labels to an PR or issue.                                         | label-documentation    |
| `	/[remove-]duplicate`            | `/duplicate`</br>`/remove-duplicate`                                    | Applies or removes the 'duplicate' labels to an PR or issue.                                             | label-duplicate        |
| `	/[remove-]enhancement`          | `/enhancement`</br>`/remove-enhancement`                                | Applies or removes the 'enhancement' labels to an PR or issue.                                           | label-enhancement      |
| `	/[remove-]invalid`              | `/invalid`</br>`/remove-invalid`                                        | Applies or removes the 'invalid' labels to an PR or issue.                                               | label-invalid          |
| `	/[remove-]question`             | `/question`</br>`/remove-question`                                      | Applies or removes the 'question' labels to an PR or issue.                                              | label-question         |
| `	/[remove-]wontfix`              | `/wontfix`</br>`/remove-wontfix`                                        | Applies or removes the 'wontfix' labels to an PR or issue.                                               | label-wontfix          |

## License

Licensed under the MIT License. See [LICENSE](https://github.com/wzshiming/gh-ci-bot/blob/master/LICENSE) for the full license text.
