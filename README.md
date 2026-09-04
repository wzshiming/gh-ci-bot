# gh-ci-bot

A CI bot for GitHub, delivered as a single GitHub [Action](examples/ci-bot.yml): it brings Prow-style chat commands and automation to your issues and pull requests, with no server to run.

It supports [Kubernetes Prow](https://github.com/kubernetes-sigs/prow) [OWNERS](https://www.kubernetes.dev/docs/guide/owners/) files, so you can use it as an alternative to GitHub [CODEOWNERS](https://github.blog/2017-07-06-introducing-code-owners/).

## Getting Started

Copy [examples/ci-bot.yml](examples/ci-bot.yml) into the `.github/workflows/` directory of your repository, then adjust the environment variables in it: the plugins enabled for each permission tier, the `REVIEWERS`/`APPROVERS`/`MAINTAINERS` lists, and feature toggles. Everything is configured through environment variables in that single workflow file; the action itself needs no inputs.

## Commands

Each command belongs to a plugin; follow the plugin link for the full documentation (syntax, examples, behavior and related environment variables).

| Command                                      | Description                                                        | Plugin                                                             |
| -------------------------------------------- | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| `/retitle <title>`                           | Edits the PR or issue title.                                       | [retitle](plugins/retitle/README.md)                               |
| `/[un]cc [[@]...]`                           | Requests or removes a review from the user(s). Must be a Member.   | [cc](plugins/cc/README.md)                                         |
| `/auto-cc`                                   | Requests reviews from randomly selected reviewers.                 | [auto-cc](plugins/auto-cc/README.md)                               |
| `/[un]assign [[@]...]`                       | Assigns or unassigns assignee(s) on the PR or issue.               | [assign](plugins/assign/README.md)                                 |
| `/[remove-]milestone [milestone]`            | Sets or clears the PR or issue milestone.                          | [milestone](plugins/milestone/README.md)                           |
| `/close`</br>`/reopen`                       | Closes or reopens a PR or issue.                                   | [lifecycle](plugins/lifecycle/README.md)                           |
| `/merge [rebase\|squash]`                    | Merges a PR.                                                       | [merge](plugins/merge/README.md)                                   |
| `/hold [cancel]`                             | Applies or removes the 'do-not-merge/hold' label, blocking merging while present. | [hold](plugins/hold/README.md)                      |
| `/retest`</br>`/test [workflow-or-job\|all]` | Reruns failed tests, or specific workflows or jobs, of a PR.       | [retest](plugins/retest/README.md)                                 |
| `/[remove-]label [...]`                      | Applies or removes the '*' labels.                                 | [label](plugins/label/README.md)                                   |
| `/[remove-]kind [...]`                       | Applies or removes the 'kind/*' labels.                            | [label-kind](plugins/label-kind/README.md)                         |
| `/[remove-]sig [...]`                        | Applies or removes the 'sig/*' labels.                             | [label-sig](plugins/label-sig/README.md)                           |
| `/[remove-]area [...]`                       | Applies or removes the 'area/*' labels.                            | [label-area](plugins/label-area/README.md)                         |
| `/[remove-]priority [...]`                   | Applies or removes the 'priority/*' labels.                        | [label-priority](plugins/label-priority/README.md)                 |
| `/[remove-]triage [...]`                     | Applies or removes the 'triage/*' labels.                          | [label-triage](plugins/label-triage/README.md)                     |
| `/[remove-]wg [...]`                         | Applies or removes the 'wg/*' labels.                              | [label-wg](plugins/label-wg/README.md)                             |
| `/[remove-]committee [...]`                  | Applies or removes the 'committee/*' labels.                       | [label-committee](plugins/label-committee/README.md)               |
| `/[remove-]lgtm`                             | Applies or removes the 'lgtm' label.                               | [label-lgtm](plugins/label-lgtm/README.md)                         |
| `/approve [cancel]`                          | Approves the PR areas the commenter owns (via OWNERS files).       | [label-approve](plugins/label-approve/README.md)                   |
| `/[remove-]help-wanted`                      | Applies or removes the 'help wanted' label.                        | [label-help-wanted](plugins/label-help-wanted/README.md)           |
| `/[remove-]good-first-issue`                 | Applies or removes the 'good first issue' label.                   | [label-good-first-issue](plugins/label-good-first-issue/README.md) |
| `/[remove-]bug`                              | Applies or removes the 'bug' label.                                | [label-bug](plugins/label-bug/README.md)                           |
| `/[remove-]documentation`                    | Applies or removes the 'documentation' label.                      | [label-documentation](plugins/label-documentation/README.md)       |
| `/[remove-]duplicate`                        | Applies or removes the 'duplicate' label.                          | [label-duplicate](plugins/label-duplicate/README.md)               |
| `/[remove-]enhancement`                      | Applies or removes the 'enhancement' label.                        | [label-enhancement](plugins/label-enhancement/README.md)           |
| `/[remove-]invalid`                          | Applies or removes the 'invalid' label.                            | [label-invalid](plugins/label-invalid/README.md)                   |
| `/[remove-]question`                         | Applies or removes the 'question' label.                           | [label-question](plugins/label-question/README.md)                 |
| `/[remove-]wontfix`                          | Applies or removes the 'wontfix' label.                            | [label-wontfix](plugins/label-wontfix/README.md)                   |
| `/release-note-none`                         | Marks the PR as not needing a release note.                        | [release-note](plugins/release-note/README.md)                     |
| `/check-dco`                                 | Re-runs the DCO signoff check of the PR.                           | [check-dco](plugins/check-dco/README.md)                           |
| `/base <branch>`                             | Changes the branch this PR will be merged into.                    | [base](plugins/base/README.md)                                     |
| `/rebase`                                    | Rebases the PR onto the latest base branch.                        | [rebase](plugins/rebase/README.md)                                 |
| `/cherry-pick <branch>`                      | Cherry-picks a merged PR to a target branch and creates a new PR.  | [cherry-pick](plugins/cherry-pick/README.md)                       |
| `/transfer-issue <repo>`                     | Transfers an issue to another repository in the same organization. | [transfer-issue](plugins/transfer-issue/README.md)                 |

### Who can run which command

Each command in the table above belongs to a plugin, named in the last column. Plugins are enabled per permission tier through environment variables, each holding a list of plugin names (one per line); a user gets the union of the plugins from all tiers they qualify for.

| Environment variable | Plugins listed are available to |
| --- | --- |
| `PLUGINS` | Anyone |
| `AUTHOR_PLUGINS` | The author of the issue or PR |
| `CONTRIBUTORS_PLUGINS` | Anyone whose author association is `CONTRIBUTOR` (has had commits merged into the repository), and every member |
| `MEMBERS_PLUGINS` | Anyone whose author association is `OWNER`, `MEMBER` or `COLLABORATOR` |
| `REVIEWERS_PLUGINS` | Members also listed in `REVIEWERS` (for PRs, merged with `reviewers` from matching OWNERS files) |
| `APPROVERS_PLUGINS` | Members also listed in `APPROVERS` (for PRs, merged with `approvers` from matching OWNERS files) |
| `MAINTAINERS_PLUGINS` | Members also listed in `MAINTAINERS` |
| `OWNERS_PLUGINS` | The repository or organization owner |

The other associations GitHub reports (`FIRST_TIME_CONTRIBUTOR`, `FIRST_TIMER`, `MANNEQUIN` and `NONE`) only get `PLUGINS`, plus `AUTHOR_PLUGINS` on their own issues and PRs.

## Automatic Behaviors

Besides commands, the bot performs some automation on its own.

### Label management

Whenever the bot adds a label (via commands like `/label`, `/kind`, `/lgtm`, `/approve`, OWNERS `labels:`, or automatic labels like `do-not-merge/work-in-progress`), any label that does not yet exist in the repository is created automatically, provided it is in the built-in default list of well-known labels or listed in the `LABELS` environment variable. Labels not in the allowlist are never created automatically (so a typo like `/label doocumentation` does not pollute the repository); they are only applied if they already exist in the repository. See [automatic label creation](plugins/label/README.md#automatic-label-creation) for the allowlist and the `LABELS` configuration.

### Work in progress

Like prow's [`wip`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/wip) plugin, the bot automatically applies the `do-not-merge/work-in-progress` label to a PR while it is a draft or its title starts with `WIP` (case-insensitive; leading spaces or punctuation are ignored, so `WIP: Title` and `[WIP] Title` also match), and removes the label once neither is true. The `do-not-merge` label and any label starting with `do-not-merge/` block both [`/merge`](plugins/merge/README.md) and auto-merge. The label is created automatically if it does not exist.

### PR size

Like prow's [`size`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/size) plugin, the bot automatically labels every PR with one of `size/XS`, `size/S`, `size/M`, `size/L`, `size/XL` or `size/XXL` based on the total number of changed lines (additions + deletions), updating the label whenever new commits are pushed. The thresholds mirror prow's defaults: XS < 10, S < 30, M < 100, L < 500, XL < 1000, XXL ≥ 1000.

### Auto-requesting reviewers

Like prow's [`blunderbuss`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/blunderbuss) plugin, the bot automatically requests reviewers when a PR is opened (like [`/auto-cc`](plugins/auto-cc/README.md) but without a manual trigger; both share the same reviewer-selection logic). Reviewers are picked from the `OWNERS` files nearest to the changed files, falling back to the `REVIEWERS` environment variable, and the PR author is never picked. Draft PRs are skipped; their reviewers are requested once the draft is marked ready for review. The number of reviewers to request is configured with the `BLUNDERBUSS_REVIEWER_COUNT` environment variable (default `2`); set it to `0` to disable the behavior (the manual `/auto-cc` command keeps working).

### Require matching label

Like prow's [`require-matching-label`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/require-matching-label) plugin, the bot automatically applies a `needs-X` label when an issue or PR is missing a label matching a configured regular expression, and removes it once a matching label is added. By default, an issue or PR without a `kind/*` label gets the `needs-kind` label, which is removed as soon as a `kind/*` label is applied (e.g. via [`/kind bug`](plugins/label-kind/README.md)). The labels are re-synced at the end of every event the bot handles, so labels the bot applies itself (e.g. from [OWNERS files](#owners-files) on a push) are also taken into account, even though they trigger no new workflow run.

The rules are configured through the `ISSUE_REQUIRE_MATCHING_LABELS` (issues) and `PR_REQUIRE_MATCHING_LABELS` (PRs) environment variables, one rule per line in the format `<missing-label> <regexp>`:

```yaml
env:
  # Issues: apply needs-kind until a kind/* label is present, and
  # needs-triage until a triage/* label is present.
  ISSUE_REQUIRE_MATCHING_LABELS: |-
    needs-kind ^kind/
    needs-triage ^triage/
  # PRs: apply do-not-merge/needs-kind until a kind/* label is present.
  # A do-not-merge/* missing label additionally blocks /merge and
  # auto-merge until a matching label is added.
  PR_REQUIRE_MATCHING_LABELS: |-
    do-not-merge/needs-kind ^kind/
```

With this configuration:

- A new issue gets `needs-kind` and `needs-triage`. Commenting `/kind bug` applies the `kind/bug` label and the bot removes `needs-kind`; `/triage accepted` applies `triage/accepted` and removes `needs-triage`. If the last `kind/*` label is removed again (`/remove-kind bug`), `needs-kind` comes back.
- A new PR gets `do-not-merge/needs-kind`, which blocks `/merge` and auto-merge like any other `do-not-merge/*` label. Once a `kind/*` label is applied (e.g. `/kind feature`), the label is removed; since [auto-merge](plugins/merge/README.md#auto-merge) is evaluated at the end of every PR event, a PR that already qualifies is merged right away.

When a variable is unset, it defaults to `needs-kind ^kind/`. Set it to an empty string to disable the check for the corresponding scope:

```yaml
env:
  # Keep the default needs-kind rule for issues, disable the check for PRs.
  PR_REQUIRE_MATCHING_LABELS: ""
```

The missing labels are created automatically if they do not exist, provided they are allowlisted like `needs-kind`, `needs-triage` or `do-not-merge/needs-kind` (see [Label management](#label-management)).

### Release notes

Like prow's [`release-note`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/releasenote) plugin, when the `RELEASE_NOTE_REQUIRED` environment variable is set to a non-empty value (it is unset by default), the bot classifies the ```` ```release-note ```` block in the PR body whenever a PR is opened, edited or pushed to, and applies exactly one of the `release-note`, `release-note-none` or `do-not-merge/release-note-label-needed` labels, blocking merge until a valid block is added or `/release-note-none` is used. See [release-note](plugins/release-note/README.md#automatic-behavior) for details.

### Needs rebase

Like prow's [`needs-rebase`](https://github.com/kubernetes-sigs/prow/tree/main/cmd/external-plugins/needs-rebase) external plugin, when the `NEEDS_REBASE` environment variable is set to a non-empty value (it is unset by default), the bot checks the PR's mergeability whenever a PR is opened, pushed to, edited or commented on. A PR that has merge conflicts with its base branch gets the `needs-rebase` label; once the conflicts are resolved, the label is removed automatically. Labels only, no comments. This complements the [`/rebase`](plugins/rebase/README.md) command, which updates a conflict-free branch to the latest base branch but cannot resolve conflicts.

GitHub computes mergeability lazily, so a conflict caused by another PR merging into the base branch may only be noticed the next time the PR is pushed to, edited or commented on.

### Merge commits

Like prow's [`mergecommitblocker`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/mergecommitblocker) plugin, when the `BLOCK_MERGE_COMMITS` environment variable is set to a non-empty value (it is unset by default), the bot applies the `do-not-merge/contains-merge-commits` label to a PR while it contains merge commits (commits with more than one parent), blocking merge until the branch is rebased, and removes the label once the merge commits are gone.

### Invalid commit messages

Like prow's [`invalidcommitmsg`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/invalidcommitmsg) plugin, when the `BLOCK_INVALID_COMMIT_MESSAGES` environment variable is set to a non-empty value (it is unset by default), the bot applies the `do-not-merge/invalid-commit-message` label to a PR while any of its commit messages or its title contains an `@mention` or a [keyword which can automatically close issues](https://docs.github.com/articles/closing-issues-using-keywords) (e.g. `fixes #42`), and removes the label once they are fixed. An invalid title can be fixed with [`/retitle`](plugins/retitle/README.md); invalid commit messages require rewording the commits.

### DCO

Like prow's [`dco`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/dco) plugin, when the `DCO_REQUIRED` environment variable is set to a non-empty value (it is unset by default), the bot checks that every commit of a PR has a `Signed-off-by` line whenever the PR is opened or pushed to, and applies the `dco-signoff: yes` or `dco-signoff: no` label accordingly. The `dco-signoff: no` label blocks [`/merge`](plugins/merge/README.md) and auto-merge, and the bot comments with the list of commits missing a signoff and instructions to fix them. Use `/check-dco` to re-run the check. See [check-dco](plugins/check-dco/README.md) for details.

## Troubleshooting

- Changes to `.github/workflows/**`
    The default `${{ secrets.GITHUB_TOKEN }}` cannot be granted the `workflows` permission (it is not in the [`permissions` block](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions)), so GitHub refuses any merge or push from it that changes a workflow file: [`/merge`](plugins/merge/README.md) and auto-merge fail, and [`/cherry-pick`](plugins/cherry-pick/README.md) cannot push its branch. The bot's reply names the workflow files when this is the cause. Set `GH_TOKEN` to a PAT with the `workflow` scope or to a GitHub App token with `workflows: write` (see `BOT_LOGIN` below), or merge or cherry-pick such PRs manually.
- Workflows not firing after bot merges, or a PR opened by the bot (e.g. by `/cherry-pick`) getting no labels
    Events performed with `GITHUB_TOKEN` do not trigger other workflows (except `workflow_dispatch` and `repository_dispatch`) to avoid recursion, so neither a bot merge nor the `opened` event of a PR the bot creates starts a run. `/cherry-pick` syncs the new PR's release-note and needs-* labels itself when it runs as `github-actions[bot]`; its other labels are applied on the PR's next event, and closing and reopening such a PR runs the same label sync as a push. If you need these events to fire on their own, use a PAT or GitHub App token. See [GitHub docs](https://docs.github.com/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow#triggering-a-workflow-from-a-workflow).
- Approvals not sticking, or a new approval status comment on every event, with a GitHub App token
    The bot finds its own comments (the approval status, the DCO notice) by author login. `GITHUB_TOKEN` and PATs resolve it through the API, but GitHub App installation tokens cannot, so the bot falls back to `github-actions[bot]` and never finds them. Set `BOT_LOGIN` to the App's login, e.g. `BOT_LOGIN: ${{ steps.app-token.outputs.app-slug }}[bot]` when the token comes from [`actions/create-github-app-token`](https://github.com/actions/create-github-app-token).

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

When an `OWNERS` file is present, the listed users are merged with any `REVIEWERS` and `APPROVERS` defined in the workflow environment variables. Labels declared under `labels:` are automatically applied to pull requests that touch files in the corresponding directories (mirroring prow's [owners-label](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/owners-label) plugin).

### Hierarchical OWNERS

OWNERS files are used hierarchically. You can place OWNERS files in any directory of your repository. For pull requests, every changed file is mapped to its *area*: the nearest ancestor directory whose OWNERS file lists at least one approver (falling back to the repository root). The approvers of an area are the approvers of that directory plus those of all parent directories, so owners of a parent directory can always approve nested areas.

For example, if `pkg/api/handler.go` and `pkg/util/helper.go` are both changed and both `pkg/api` and `pkg/util` contain an OWNERS file with approvers, the PR has two areas: `pkg/api` and `pkg/util`. Each area can be approved by its own approvers or by approvers from `pkg` or the root OWNERS file.

The [`/auto-cc`](plugins/auto-cc/README.md) command and the automatic [blunderbuss](#auto-requesting-reviewers) behavior share the same logic: they walk up from each individual changed file to find the nearest OWNERS file with available reviewers.

## Testing

The test suite lives in [`test/`](test/README.md); see its README for how to run and write tests.

## Roadmap

- Continue closing the gap with [Prow](https://github.com/kubernetes-sigs/prow) plugins.

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for the full license text.
