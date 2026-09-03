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
| `MEMBERS_PLUGINS` | Anyone whose author association is not `NONE` (members, collaborators, previous contributors) |
| `REVIEWERS_PLUGINS` | Members also listed in `REVIEWERS` (for PRs, merged with `reviewers` from matching OWNERS files) |
| `APPROVERS_PLUGINS` | Members also listed in `APPROVERS` (for PRs, merged with `approvers` from matching OWNERS files) |
| `MAINTAINERS_PLUGINS` | Members also listed in `MAINTAINERS` |
| `OWNERS_PLUGINS` | The repository or organization owner |

## Automatic Behaviors

Besides commands, the bot performs some automation on its own. Each behavior is documented in its plugin directory:

| Behavior                  | Description                                                                                                       | Plugin                                                                     |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Label management          | Creates missing well-known or `LABELS`-allowlisted labels whenever the bot applies them.                          | [label](plugins/label/README.md#automatic-label-creation)                  |
| Work in progress          | Applies 'do-not-merge/work-in-progress' while a PR is a draft or titled `WIP`, blocking merging.                  | [wip](plugins/wip/README.md)                                               |
| PR size                   | Labels every PR with 'size/*' based on the number of changed lines.                                               | [size](plugins/size/README.md)                                             |
| Auto-requesting reviewers | Requests reviewers from the OWNERS files nearest to the changed files when a PR is opened.                        | [blunderbuss](plugins/blunderbuss/README.md)                               |
| Require matching label    | Applies 'needs-*' labels while a required label (by default 'kind/*') is missing.                                 | [require-matching-label](plugins/require-matching-label/README.md)         |
| Release notes             | Syncs the release-note labels from the `release-note` block in PR bodies, blocking merge until one applies. Opt-in. | [release-note](plugins/release-note/README.md#automatic-behavior)          |

## Troubleshooting

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

When an `OWNERS` file is present, the listed users are merged with any `REVIEWERS` and `APPROVERS` defined in the workflow environment variables. Labels declared under `labels:` are automatically applied to pull requests that touch files in the corresponding directories (mirroring prow's [owners-label](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/owners-label) plugin).

### Hierarchical OWNERS

OWNERS files are used hierarchically. You can place OWNERS files in any directory of your repository. For pull requests, every changed file is mapped to its *area*: the nearest ancestor directory whose OWNERS file lists at least one approver (falling back to the repository root). The approvers of an area are the approvers of that directory plus those of all parent directories, so owners of a parent directory can always approve nested areas.

For example, if `pkg/api/handler.go` and `pkg/util/helper.go` are both changed and both `pkg/api` and `pkg/util` contain an OWNERS file with approvers, the PR has two areas: `pkg/api` and `pkg/util`. Each area can be approved by its own approvers or by approvers from `pkg` or the root OWNERS file.

The [`/auto-cc`](plugins/auto-cc/README.md) command and the automatic [blunderbuss](plugins/blunderbuss/README.md) behavior share the same logic: they walk up from each individual changed file to find the nearest OWNERS file with available reviewers.

## Testing

The test suite in [`test/`](test/) runs the real scripts (`bin/*.sh`, `plugins/**/*.plugin.sh`, `entrypoint.sh`) against a mocked `gh` (and `curl`) that logs every invocation and serves canned JSON fixtures, so nothing ever talks to GitHub. It is pure bash with no dependencies beyond `bash` and `jq`, and runs on every push and pull request via [`.github/workflows/test.yml`](.github/workflows/test.yml).

Run the whole suite locally:

```bash
./test/run.sh
```

Or only some specs, by name:

```bash
./test/run.sh release-note check-wip
```

Specs live in [`test/specs/`](test/specs/); the assertion, log and fixture helpers they use are documented in [`test/lib.sh`](test/lib.sh). On macOS, install GNU coreutils first (`brew install coreutils`) because the scripts use `realpath -m`; CI's ubuntu runners work out of the box.

## Roadmap

- Continue closing the gap with [Prow](https://github.com/kubernetes-sigs/prow) plugins.

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for the full license text.
