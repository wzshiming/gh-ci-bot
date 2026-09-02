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
| `/hold [cancel]`                  | `/hold`</br>`/hold cancel`                             | Applies or removes the 'do-not-merge/hold' label, blocking `/merge` and auto-merge while present.                                 | hold                   |
| `/retest`                         | `/retest`                                              | Retest all failed test of PR.                                                                                                                                                        | retest                 |
| `/test [workflow-or-job\|all]`    | `/test all`</br>`/test CI`</br>`/test unit-test`       | Reruns a specific workflow or job for a PR by name, or all of them with `all`.                                                                                                          | retest                 |
| `/ok-to-test`                     | `/ok-to-test`                                          | Marks an external contributor's PR as safe to test: adds the 'ok-to-test' label, removes 'needs-ok-to-test', and approves the PR's pending workflow runs, now and on future pushes.  | ok-to-test             |
| `/[remove-]kind [...]`            | `/kind doc`</br>`/remove-kind doc`                     | Applies or removes the 'kind/*' labels to an PR or issue.                                                                         | label-kind             |
| `/[remove-]sig [...]`             | `/sig node`</br>`/remove-sig node`                     | Applies or removes the 'sig/*' labels to an PR or issue.                                                                          | label-sig              |
| `/[remove-]area [...]`            | `/area api`</br>`/remove-area api`                     | Applies or removes the 'area/*' labels to an PR or issue.                                                                         | label-area             |
| `/[remove-]priority [...]`        | `/priority backlog`</br>`/remove-priority backlog`     | Applies or removes the 'priority/*' labels to an PR or issue.                                                                     | label-priority         |
| `/[remove-]triage [...]`          | `/triage accepted`</br>`/remove-triage accepted`       | Applies or removes the 'triage/*' labels to an PR or issue.                                                                       | label-triage           |
| `/[remove-]wg [...]`              | `/wg policy`</br>`/remove-wg policy`                   | Applies or removes the 'wg/*' labels to an PR or issue.                                                                           | label-wg               |
| `/[remove-]committee [...]`       | `/committee steering`</br>`/remove-committee steering` | Applies or removes the 'committee/*' labels to an PR or issue.                                                                    | label-committee        |
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
| `/release-note-none`              | `/release-note-none`                                   | Applies the 'release-note-none' label, marking the PR as not needing a release note. Fails if the PR body's release-note block contains a note.   | release-note           |
| `/base [branch]`                  | `/base main`                                           | Change to which branch this PR is to be merged into                                                                                                                                  | base                   |
| `/rebase`                         | `/rebase`                                              | Rebase the this PR to the latest of the branch                                                                                                                                       | rebase                 |
| `/cherry-pick [branch]`           | `/cherry-pick release-1.0`                             | Cherry-pick a merged PR to a target branch and create a new PR                                                                                                                       | cherry-pick            |
| `/transfer-issue [repo]`          | `/transfer-issue other-repo`                           | Transfers an issue to another repository in the same organization                                                                                                                    | transfer-issue         |

### Label management

Whenever the bot adds a label (via commands like `/label`, `/kind`, `/lgtm`, `/approve`, OWNERS `labels:`, or automatic labels like `do-not-merge/work-in-progress`), any label that does not yet exist in the repository is created automatically, provided it is in the built-in default list of well-known labels or listed in the `LABELS` environment variable. Labels not in the allowlist are never created automatically (so a typo like `/label doocumentation` does not pollute the repository); they are only applied if they already exist in the repository.

The prow-style label families all work the same way: `/kind`, `/sig`, `/area`, `/priority`, `/triage`, `/wg` and `/committee` (and their `/remove-*` counterparts) apply or remove a `<family>/<value>` label. The standard prow `kind/*`, `priority/*` and `triage/*` labels are in the built-in allowlist and are created on demand; `sig/*`, `area/*`, `wg/*` and `committee/*` values are organization-specific, so they are only applied if the label already exists in the repository, unless allowlisted through `LABELS` (e.g. a `sig/` prefix entry).

### Work in progress

Like prow's `wip` plugin, the bot automatically applies the `do-not-merge/work-in-progress` label to a PR while it is a draft or its title starts with `WIP`, and removes the label once neither is true. Any label starting with `do-not-merge/` blocks both `/merge` and auto-merge. The label is created automatically if it does not exist.

### PR size

Like prow's `size` plugin, the bot automatically labels every PR with one of `size/XS`, `size/S`, `size/M`, `size/L`, `size/XL` or `size/XXL` based on the total number of changed lines (additions + deletions), updating the label whenever new commits are pushed. The thresholds mirror prow's defaults: XS < 10, S < 30, M < 100, L < 500, XL < 1000, XXL ≥ 1000.

### Auto-requesting reviewers

Like prow's `blunderbuss` plugin, the bot automatically requests reviewers when a PR is opened (like `/auto-cc` but without a manual trigger; both share the same reviewer-selection logic). Reviewers are picked from the `OWNERS` files nearest to the changed files, falling back to the `REVIEWERS` environment variable, and the PR author is never picked. Draft PRs are skipped. The number of reviewers to request is configured with the `BLUNDERBUSS_REVIEWER_COUNT` environment variable (default `2`); set it to `0` to disable the behavior (the manual `/auto-cc` command keeps working).

### Require matching label

Like prow's `require-matching-label` plugin, the bot automatically applies a `needs-X` label when an issue or PR is missing a label matching a configured regular expression, and removes it once a matching label is added. By default, an issue or PR without a `kind/*` label gets the `needs-kind` label, which is removed as soon as a `kind/*` label is applied (e.g. via `/kind bug`).

The rules are configured through the `ISSUE_REQUIRE_MATCHING_LABELS` (issues) and `PR_REQUIRE_MATCHING_LABELS` (PRs) environment variables, one rule per line in the format `<missing-label> <regexp>`:

```yaml
env:
  ISSUE_REQUIRE_MATCHING_LABELS: |-
    needs-kind ^kind/
  PR_REQUIRE_MATCHING_LABELS: |-
    do-not-merge/needs-kind ^kind/
    needs-priority ^priority/
```

Set a variable to an empty string to disable the check for the corresponding scope. Using a `do-not-merge/*` missing label (e.g. `do-not-merge/needs-kind` for PRs) additionally blocks `/merge` and auto-merge until a matching label is added.

### Release notes

Like prow's `release-note` plugin, when the `RELEASE_NOTE_REQUIRED` environment variable is set to a non-empty value (it is unset by default), the bot parses a fenced code block from the PR body whenever a PR is opened, edited or pushed to:

````
```release-note
Added a feature.
```
````

and applies exactly one of these mutually exclusive labels, removing the others:

| Block content             | Label                                    |
| ------------------------- | ---------------------------------------- |
| `NONE` (case-insensitive) | `release-note-none`                      |
| any other non-empty text  | `release-note`                           |
| block missing or empty    | `do-not-merge/release-note-label-needed` |

`do-not-merge/release-note-label-needed` blocks `/merge` and auto-merge like any other `do-not-merge/*` label, until a valid block is added or `/release-note-none` is used. The `/release-note-none` command is available to whoever the `release-note` plugin is enabled for, even when `RELEASE_NOTE_REQUIRED` is unset.

### Ok to test

Like prow's [`trigger`](https://github.com/kubernetes/test-infra/tree/master/prow/plugins/trigger) plugin, the bot can hold back CI on pull requests from external contributors until someone trusted vouches for them. When the `OK_TO_TEST_REQUIRED` environment variable is set to a non-empty value (it is unset by default), a PR opened by an untrusted author — one whose author association is not `OWNER`, `MEMBER` or `COLLABORATOR` and who is not listed in the `REVIEWERS`, `APPROVERS` or `MAINTAINERS` environment variables — gets the `needs-ok-to-test` label and a comment asking a reviewer to reply with `/ok-to-test`.

`/ok-to-test` adds the `ok-to-test` label, removes `needs-ok-to-test` and approves all of the PR's workflow runs that are waiting for approval, automating the "Approve and run" button GitHub shows for runs of first-time contributors (approving requires the `actions: write` permission, which the example workflow already grants). For runs the approve API rejects — it only covers fork PRs, while runs of same-repo PRs (such as those pushed by the Copilot coding agent) can be held for approval too — the bot falls back to re-running them, which starts them all the same. The label is sticky: while it is present, workflow runs waiting for approval are approved automatically on every push, so one `/ok-to-test` covers the whole PR lifetime; remove the label to go back to manual approval. The command works whenever the `ok-to-test` plugin is enabled, even when `OK_TO_TEST_REQUIRED` is unset.

The plugin is suggested for `REVIEWERS_PLUGINS` rather than `MEMBERS_PLUGINS`: the command dispatcher counts any author association other than `NONE` — including `CONTRIBUTOR` — as a member, which is too weak a bar for vouching. Since the bot itself runs on `pull_request_target` and is therefore never held back by workflow-run approval, your own `pull_request`-triggered workflows can additionally require the label explicitly:

```yaml
jobs:
  test:
    if: >-
      contains(fromJSON('["OWNER", "MEMBER", "COLLABORATOR"]'), github.event.pull_request.author_association) ||
      contains(github.event.pull_request.labels.*.name, 'ok-to-test')
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

The `/auto-cc` command and the automatic blunderbuss behavior share the same logic: they walk up from each individual changed file to find the nearest OWNERS file with available reviewers.

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

- https://github.com/kubernetes/test-infra/tree/master/prow

## License

Licensed under the MIT License. See [LICENSE](https://github.com/wzshiming/gh-ci-bot/blob/master/LICENSE) for the full license text.
