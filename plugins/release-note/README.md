# release-note

Manages the release-note labels of a pull request, mirroring prow's [`release-note`](https://github.com/kubernetes-sigs/prow/tree/main/pkg/plugins/releasenote) plugin.

## Commands

| Command              | Example              | Description                                                                                                                                     |
| -------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/release-note-none` | `/release-note-none` | Applies the `release-note-none` label, marking the PR as not needing a release note. Fails if the PR body's release-note block contains a note.   |

The command is available to whoever the `release-note` plugin is enabled for, even when `RELEASE_NOTE_REQUIRED` is unset.

## Automatic behavior

When the `RELEASE_NOTE_REQUIRED` environment variable is set to a non-empty value (it is unset by default), the bot parses a fenced code block from the PR body whenever a PR is opened, edited or pushed to:

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

`do-not-merge/release-note-label-needed` blocks [`/merge`](../merge/README.md) and auto-merge like any other `do-not-merge/*` label, until a valid block is added or `/release-note-none` is used.

Like in prow, `/release-note-none` is sticky: once the `release-note-none` label is applied, a missing or empty block does not replace it with `do-not-merge/release-note-label-needed`. A block containing an actual note still takes precedence and switches the labels.

The labels are created automatically if they do not exist (see [automatic label creation](../label/README.md#automatic-label-creation)).

## Configuration

| Environment variable    | Description                                                                                              |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| `RELEASE_NOTE_REQUIRED` | Set to a non-empty value to sync the release-note labels from the PR body. Unset (the default) to disable. |
