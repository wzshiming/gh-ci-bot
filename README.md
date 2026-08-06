# gh-ci-bot

Simply introducing a [Action](https://github.com/wzshiming/gh-ci-bot/blob/master/examples/ci-bot.yml) gives you the ability to execute the following commands on Issue/PR.

It supports [Kubernetes Prow OWNERS](https://github.com/kubernetes/test-infra/tree/master/prow) files, so you can use it as an alternative to GitHub [CODEOWNERS](https://github.blog/2017-07-06-introducing-code-owners/).

| Command                           | Example                                                | Description                                                                                                                                                                          | Plugin                 |
| --------------------------------- | ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------- |
| `/retitle`                        | `/retitle New Title`                                   | Edits the PR or issue title.                                                                                                                                                         | retitle                |
| `/[un]cc [[@]...]`                | `/cc`</br>`/uncc`</br>`/cc @wzshiming`                 | Requests a review from the user(s). Must be a Member.                                                                                                                                | cc                     |
| `/auto-cc`                        | `/auto-cc`                                             | Requests a review from the random Reviewer.                                                                                                                                          | auto-cc                |
| `/[un]assign [[@]...]`            | `/assign`</br>`/unassign`</br>`/assign @wzshiming`     | Assigns assignee(s) to the PR or issue.                                                                                                                                              | assign                 |
| `/[remove-]milestone [milestone]` | `/milestone v1.0.0`</br>`/remove-milestone`            | Edits the PR or issue milestone. **Milestone need to be created manually in advance.**                                                                                               | milestone              |
| `/close`                          | `/close`                                               | Closes an PR or issue.                                                                                                                                                               | lifecycle              |
| `/reopen`                         | `/reopen`                                              | Reopen an PR or issue.                                                                                                                                                               | lifecycle              |
| `/merge [rebase\|squash]`         | `/merge`</br>`/merge rebase`</br>`/merge squash`       | Merge a PR.                                                                                                                                                                          | merge                  |
| `/retest`                         | `/retest`                                              | Retest all failed test of PR.                                                                                                                                                        | retest                 |
| `/[remove-]kind [...]`            | `/kind doc`</br>`/remove-kind doc`                     | Applies or removes the 'kind/*' labels to an PR or issue.                                                                         | kind                   |
| `/[remove-]label [...]`           | `/label doc`</br>`/remove-label doc`                   | Applies or removes the '*' labels to an PR or issue.                                                                              | label                  |
| `/[remove-]lgtm`                  | `/lgtm`</br>`/remove-lgtm`                             | Applies or removes the 'lgtm' label. Removed automatically on new commits. Auto-merges with 'approved'.                           | label-lgtm             |
| `/approve [cancel]`               | `/approve`</br>`/approve cancel`</br>`/remove-approve` | Approves the PR areas the commenter owns (via OWNERS files); adds 'approved' once all areas are covered. Auto-merges with 'lgtm'. | label-approve          |
| `/[remove-]help-wanted`           | `/help-wanted`</br>`/remove-help-wanted`               | Applies or removes the 'help wanted' labels to an PR or issue.                                                                                                                       | label-help-wanted      |
| `/[remove-]good-first-issue`      | `/good-first-issue`</br>`/remove-good-first-issue`     | Applies or removes the 'good first issue' labels to an PR or issue.                                                                                                                  | label-good-first-issue |
| `/[remove-]bug`                   | `/bug`</br>`/remove-bug`                               | Applies or removes the 'bug' labels to an PR or issue.                                                                                                                               | label-bug              |
| `/[remove-]documentation`         | `/documentation`</br>`/remove-documentation`           | Applies or removes the 'documentation' labels to an PR or issue.                                                                                                                     | label-documentation    |
| `/[remove-]duplicate`             | `/duplicate`</br>`/remove-duplicate`                   | Applies or removes the 'duplicate' labels to an PR or issue.                                                                                                                         | label-duplicate        |
| `/[remove-]enhancement`           | `/enhancement`</br>`/remove-enhancement`               | Applies or removes the 'enhancement' labels to an PR or issue.                                                                                                                       | label-enhancement      |
| `/[remove-]invalid`               | `/invalid`</br>`/remove-invalid`                       | Applies or removes the 'invalid' labels to an PR or issue.                                                                                                                           | label-invalid          |
| `/[remove-]question`              | `/question`</br>`/remove-question`                     | Applies or removes the 'question' labels to an PR or issue.                                                                                                                          | label-question         |
| `/[remove-]wontfix`               | `/wontfix`</br>`/remove-wontfix`                       | Applies or removes the 'wontfix' labels to an PR or issue.                                                                                                                           | label-wontfix          |
| `/base [branch]`                  | `/base main`                                           | Change to which branch this PR is to be merged into                                                                                                                                  | base                   |
| `/rebase`                         | `/rebase`                                              | Rebase the this PR to the latest of the branch                                                                                                                                       | rebase                 |
| `/cherry-pick [branch]`           | `/cherry-pick release-1.0`                             | Cherry-pick a merged PR to a target branch and create a new PR                                                                                                                       | cherry-pick            |
| `/transfer-issue [repo]`          | `/transfer-issue other-repo`                           | Transfers an issue to another repository in the same organization                                                                                                                    | transfer-issue         |

### Label management

Whenever the bot adds a label (via commands like `/label`, `/kind`, `/lgtm`, `/approve`, OWNERS `labels:`, or automatic labels like `do-not-merge/work-in-progress`), any label that does not yet exist in the repository is created automatically with a well-known color and description. Colors and descriptions are synchronized with prow's [label definitions](https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.yaml) (e.g. `lgtm`, `approved`, `do-not-merge/*`, `kind/*`, `good first issue`, `help wanted`); GitHub's built-in labels (e.g. `bug`, `question`) keep their standard GitHub colors and descriptions, and any other label is created with GitHub's default gray color. Labels no longer need to be created manually in advance.

### Work in progress

Like prow's `wip` plugin, the bot automatically applies the `do-not-merge/work-in-progress` label to a PR while it is a draft or its title starts with `WIP`, and removes the label once neither is true. Any label starting with `do-not-merge/` blocks both `/merge` and auto-merge. The label is created automatically if it does not exist.

### PR size

Like prow's `size` plugin, the bot automatically labels every PR with one of `size/XS`, `size/S`, `size/M`, `size/L`, `size/XL` or `size/XXL` based on the total number of changed lines (additions + deletions), updating the label whenever new commits are pushed. The thresholds mirror prow's defaults: XS < 10, S < 30, M < 100, L < 500, XL < 1000, XXL ≥ 1000.

Generated files are excluded from the count: files marked [`linguist-generated`](https://docs.github.com/en/repositories/working-with-files/managing-files/customizing-how-changed-files-appear-on-github) in the `.gitattributes` file at the repository root — the same attribute GitHub itself uses to hide generated files in diffs — are ignored:

```
*.pb.go linguist-generated=true
generated/** linguist-generated=true
```

### Troubleshooting

- `/cherry-pick`
    If you encounter the error `pull request create failed: GraphQL: GitHub Actions is not permitted to create or approve pull requests (createPullRequest)`,
    go to your repository settings under the Actions section and check `Allow GitHub Actions to create and approve pull requests`.
- Changes to `.github/**`
    The default `${{ secrets.GITHUB_TOKEN }}` is read-only on pull request runs, so it cannot merge workflow or other `.github` changes on your behalf. Use a PAT or GitHub App token with `contents`/`pull_requests`/`workflows` write access instead. See [GitHub docs](https://docs.github.com/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token).
- Workflows not firing after bot merges
    Events performed with `GITHUB_TOKEN` do not trigger other workflows (except `workflow_dispatch` and `repository_dispatch`) to avoid recursion. If you need a merge to kick off another workflow, use a PAT or GitHub App token. See [GitHub docs](https://docs.github.com/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).

## OWNERS Files

The bot supports Prow-style `OWNERS` files for defining reviewers and approvers at any directory level in your repository. This makes it a drop-in alternative when you want to manage ownership outside GitHub `CODEOWNERS`. An `OWNERS` file is a YAML file with the following format:

```yaml
reviewers:
- reviewer1
- reviewer2
approvers:
- approver1
- approver2
labels:
- label1
- label2
```

When an `OWNERS` file is present, the listed users are merged with any `REVIEWERS` and `APPROVERS` defined in the workflow environment variables. Labels declared under `labels:` are automatically applied to pull requests that touch files in the corresponding directories (mirroring prow's [owners-label](https://github.com/kubernetes/test-infra/tree/master/prow) plugin).

### Hierarchical OWNERS

OWNERS files are used hierarchically. You can place OWNERS files in any directory of your repository. For pull requests, every changed file is mapped to its *area*: the nearest ancestor directory whose OWNERS file lists at least one approver (falling back to the repository root). The approvers of an area are the approvers of that directory plus those of all parent directories, so owners of a parent directory can always approve nested areas.

For example, if `pkg/api/handler.go` and `pkg/util/helper.go` are both changed and both `pkg/api` and `pkg/util` contain an OWNERS file with approvers, the PR has two areas: `pkg/api` and `pkg/util`. Each area can be approved by its own approvers or by approvers from `pkg` or the root OWNERS file.

The `/auto-cc` command additionally walks up from each individual changed file to find the nearest OWNERS file with available reviewers.

## Roadmap

- https://github.com/kubernetes/test-infra/tree/master/prow

## License

Licensed under the MIT License. See [LICENSE](https://github.com/wzshiming/gh-ci-bot/blob/master/LICENSE) for the full license text.
