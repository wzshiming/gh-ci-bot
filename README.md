# gh-ci-bot

Simply introducing a [Action](https://github.com/wzshiming/gh-ci-bot/blob/master/examples/ci-bot.yml) gives you the ability to execute the following commands on Issue/PR.

It is better to use with [CodeOwners of Github](https://github.blog/2017-07-06-introducing-code-owners/).

| Command                           | Example                                            | Description                                                                                                  | Plugin                 |
| --------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------- |
| `/retitle`                        | `/retitle New Title`                               | Edits the PR or issue title.                                                                                 | retitle                |
| `/[un]cc [[@]...]`                | `/cc`</br>`/uncc`</br>`/cc @wzshiming`             | Requests a review from the user(s). Must be a Member.                                                        | cc                     |
| `/auto-cc`                        | `/auto-cc`                                         | Requests a review from the random Reviewer.                                                                  | auto-cc                |
| `/[un]assign [[@]...]`            | `/assign`</br>`/unassign`</br>`/assign @wzshiming` | Assigns assignee(s) to the PR or issue.                                                                      | assign                 |
| `/[remove-]milestone [milestone]` | `/milestone v1.0.0`</br>`/remove-milestone`        | Edits the PR or issue milestone. **Milestone need to be created manually in advance.**                       | milestone              |
| `/close`                          | `/close`                                           | Closes an PR or issue.                                                                                       | lifecycle              |
| `/reopen`                         | `/reopen`                                          | Reopen an PR or issue.                                                                                       | lifecycle              |
| `/merge [rebase\|squash]`         | `/merge`</br>`/merge rebase`</br>`/merge squash`   | Merge a PR.                                                                                                  | merge                  |
| `/retest`                         | `/retest`                                          | Retest all failed test of PR.                                                                                | retest                 |
| `/[remove-]kind [...]`            | `/kind doc`</br>`/remove-kind doc`                 | Applies or removes the 'kind/*' labels to an PR or issue. **Labels need to be created manually in advance.** | kind                   |
| `/[remove-]label [...]`           | `/label doc`</br>`/remove-label doc`               | Applies or removes the '*' labels to an PR or issue. **Labels need to be created manually in advance.**      | label                  |
| `/[remove-]lgtm`                  | `/lgtm`</br>`/remove-lgtm`                         | Applies or removes the 'lgtm' labels to an PR or issue. For PRs, the 'lgtm' label is automatically removed when new commits are pushed. **Labels need to be created manually in advance.**   | lgtm                   |
| `/[remove-]help-wanted`           | `/help-wanted`</br>`/remove-help-wanted`           | Applies or removes the 'help wanted' labels to an PR or issue.                                               | label-help-wanted      |
| `/[remove-]good-first-issue`      | `/good-first-issue`</br>`/remove-good-first-issue` | Applies or removes the 'good first issue' labels to an PR or issue.                                          | label-good-first-issue |
| `/[remove-]bug`                   | `/bug`</br>`/remove-bug`                           | Applies or removes the 'bug' labels to an PR or issue.                                                       | label-bug              |
| `/[remove-]documentation`         | `/documentation`</br>`/remove-documentation`       | Applies or removes the 'documentation' labels to an PR or issue.                                             | label-documentation    |
| `/[remove-]duplicate`             | `/duplicate`</br>`/remove-duplicate`               | Applies or removes the 'duplicate' labels to an PR or issue.                                                 | label-duplicate        |
| `/[remove-]enhancement`           | `/enhancement`</br>`/remove-enhancement`           | Applies or removes the 'enhancement' labels to an PR or issue.                                               | label-enhancement      |
| `/[remove-]invalid`               | `/invalid`</br>`/remove-invalid`                   | Applies or removes the 'invalid' labels to an PR or issue.                                                   | label-invalid          |
| `/[remove-]question`              | `/question`</br>`/remove-question`                 | Applies or removes the 'question' labels to an PR or issue.                                                  | label-question         |
| `/[remove-]wontfix`               | `/wontfix`</br>`/remove-wontfix`                   | Applies or removes the 'wontfix' labels to an PR or issue.                                                   | label-wontfix          |
| `/base [branch]`                  | `/base main`                                       | Change to which branch this PR is to be merged into                                                          | base                   |
| `/rebase`                         | `/rebase`                                          | Rebase the this PR to the latest of the branch                                                               | rebase                 |

## Roadmap

- https://github.com/kubernetes/test-infra/tree/master/prow

## License

Licensed under the MIT License. See [LICENSE](https://github.com/wzshiming/gh-ci-bot/blob/master/LICENSE) for the full license text.
