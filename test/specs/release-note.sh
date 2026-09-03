#!/usr/bin/env bash

# Seed suite ported from the harness used to verify the release-note
# feature (#134): classification of the ```release-note block, the label
# sync in check-release-note.sh, the /release-note-none command, the
# ensure-labels.sh allowlist, and the entrypoint.sh TYPE=edited dispatch.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

RELEASE_NOTE_LABEL="release-note"
NONE_LABEL="release-note-none"
NEEDED_LABEL="do-not-merge/release-note-label-needed"

NOTE_BODY=$'Fixes #42.\n\n```release-note\nAdded a `--fonts` flag.\n```'
NONE_BODY=$'```release-note\nNONE\n```'
EMPTY_BODY=$'Fixes #42.\n\n```release-note\n```'

# stub_label_scripts swaps the label helpers for logging no-ops, so the
# script under test is exercised in isolation and the log records exactly
# which labels it wanted to change.
function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

# --- release-note.sh: classify the block in the PR body ----------------

# classify <description> <expected-label>: pipe the PR body on stdin
# through release-note.sh and expect the given label.
function classify() {
    begin_case "release-note.sh: ${1}"
    run release-note.sh
    assert_status 0
    assert_out_is "${2}"
    log_empty
}

classify "a filled block is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
Fixes #42.

```release-note
Added a `--fonts` flag.
```
EOF

classify "a multi-line block is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
```release-note
Added a `--fonts` flag.
Deprecated the `--glyphs` flag.
```
EOF

classify "an action-required block is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
```release-note
action required: the old config file format is no longer read.
```
EOF

classify "text before and after the block is ignored" "${RELEASE_NOTE_LABEL}" <<'EOF'
Long description of the change.

```release-note
Some note.
```

/assign @alice
EOF

classify "NONE is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
NONE
```
EOF

classify "lowercase none is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
none
```
EOF

classify "mixed-case None is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
None
```
EOF

classify "quoted \"NONE\" is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
"NONE"
```
EOF

classify "backticked NONE is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
`NONE`
```
EOF

classify "NONE with a trailing period is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note
NONE.
```
EOF

classify "NONE padded with blank lines is release-note-none" "${NONE_LABEL}" <<'EOF'
```release-note


NONE

```
EOF

classify "a word merely starting with none is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
```release-note
nonessential cleanup of the renderer.
```
EOF

classify "none followed by other words is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
```release-note
none of the flags changed, but the defaults did.
```
EOF

classify "NONE on two lines is a release note" "${RELEASE_NOTE_LABEL}" <<'EOF'
```release-note
NONE
NONE
```
EOF

classify "an empty block still needs a label" "${NEEDED_LABEL}" <<'EOF'
```release-note
```
EOF

classify "a whitespace-only block still needs a label" "${NEEDED_LABEL}" <<'EOF'
```release-note

	
```
EOF

classify "an empty body still needs a label" "${NEEDED_LABEL}" </dev/null

classify "a body without a block still needs a label" "${NEEDED_LABEL}" <<'EOF'
Just a description, no release-note block anywhere.
EOF

classify "NONE outside a block still needs a label" "${NEEDED_LABEL}" <<'EOF'
NONE
EOF

classify "NONE in a different code block still needs a label" "${NEEDED_LABEL}" <<'EOF'
```text
NONE
```
EOF

classify "an unclosed block with a note still needs a label" "${NEEDED_LABEL}" <<'EOF'
```release-note
Added a `--fonts` flag.
EOF

classify "an unclosed block with NONE still needs a label" "${NEEDED_LABEL}" <<'EOF'
```release-note
NONE
EOF

classify "a CRLF note is a release note" "${RELEASE_NOTE_LABEL}" \
    < <(printf 'Fixes #42.\r\n\r\n```release-note\r\nAdded a flag.\r\n```\r\n')

classify "a CRLF NONE is release-note-none" "${NONE_LABEL}" \
    < <(printf '```release-note\r\nNONE\r\n```\r\n')

classify "a CRLF empty block still needs a label" "${NEEDED_LABEL}" \
    < <(printf '```release-note\r\n```\r\n')

classify "the fence language tag is case-insensitive" "${RELEASE_NOTE_LABEL}" <<'EOF'
```RELEASE-NOTE
Added a flag.
```
EOF

classify "trailing whitespace after the fence tag is tolerated" "${NONE_LABEL}" \
    < <(printf '```release-note \t\nNONE\n```\n')

# --- check-release-note.sh: sync the labels on the PR ------------------

begin_case "check-release-note.sh: does nothing unless RELEASE_NOTE_REQUIRED is set"
stub_label_scripts
mkpr "${NOTE_BODY}"
run check-release-note.sh
assert_status 0
log_empty

begin_case "check-release-note.sh: does nothing for issues"
export RELEASE_NOTE_REQUIRED=1
export ISSUE_KIND="issue"
stub_label_scripts
run check-release-note.sh
assert_status 0
log_empty

begin_case "check-release-note.sh: never mutates labels when the PR query fails"
export RELEASE_NOTE_REQUIRED=1
export MOCK_GH_FAIL=1
stub_label_scripts
run check-release-note.sh
assert_status 0
assert_out_has "Failed to get the pull request"
log_has "view 1 --json body,labels"
log_lacks "stub"

begin_case "check-release-note.sh: adds release-note to an unlabeled PR with a note"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NOTE_BODY}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${RELEASE_NOTE_LABEL}"
log_lacks "stub remove-labels.sh"
log_lacks "stub check-auto-merge.sh"

begin_case "check-release-note.sh: leaves a correctly labeled PR alone"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NOTE_BODY}" "${RELEASE_NOTE_LABEL}" "kind/bug"
run check-release-note.sh
assert_status 0
log_has "view 1 --json body,labels"
log_lacks "stub"

begin_case "check-release-note.sh: a note replaces release-note-none without auto-merge"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NOTE_BODY}" "${NONE_LABEL}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${RELEASE_NOTE_LABEL}"
log_has_line "stub remove-labels.sh ${NONE_LABEL}"
log_lacks "stub check-auto-merge.sh"

begin_case "check-release-note.sh: a note replaces the needed label without evaluating auto-merge"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NOTE_BODY}" "${NEEDED_LABEL}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${RELEASE_NOTE_LABEL}"
log_has_line "stub remove-labels.sh ${NEEDED_LABEL}"
log_lacks "stub check-auto-merge.sh"

begin_case "check-release-note.sh: an empty block adds the needed label"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${EMPTY_BODY}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${NEEDED_LABEL}"
log_lacks "stub remove-labels.sh"
log_lacks "stub check-auto-merge.sh"

begin_case "check-release-note.sh: an emptied block downgrades release-note to needed"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${EMPTY_BODY}" "${RELEASE_NOTE_LABEL}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${NEEDED_LABEL}"
log_has_line "stub remove-labels.sh ${RELEASE_NOTE_LABEL}"

begin_case "check-release-note.sh: release-note-none is sticky against an empty block"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${EMPTY_BODY}" "${NONE_LABEL}"
run check-release-note.sh
assert_status 0
log_has "view 1 --json body,labels"
log_lacks "stub"

begin_case "check-release-note.sh: sticky release-note-none still clears a stale needed label"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${EMPTY_BODY}" "${NONE_LABEL}" "${NEEDED_LABEL}"
run check-release-note.sh
assert_status 0
log_lacks "stub add-labels.sh"
log_has_line "stub remove-labels.sh ${NEEDED_LABEL}"
log_lacks "stub check-auto-merge.sh"

begin_case "check-release-note.sh: NONE replaces release-note with release-note-none"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NONE_BODY}" "${RELEASE_NOTE_LABEL}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"
log_has_line "stub remove-labels.sh ${RELEASE_NOTE_LABEL}"

begin_case "check-release-note.sh: NONE labels an unlabeled PR release-note-none"
export RELEASE_NOTE_REQUIRED=1
stub_label_scripts
mkpr "${NONE_BODY}"
run check-release-note.sh
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "check-release-note.sh: full stack, real label scripts edit the PR via gh"
export RELEASE_NOTE_REQUIRED=1
mkpr "${NOTE_BODY}" "${NEEDED_LABEL}" "kind/bug"
run check-release-note.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${RELEASE_NOTE_LABEL}"
log_has_line "gh pr -R wzshiming/example edit 1 --remove-label ${NEEDED_LABEL}"
log_lacks "view 1 --json labels"
log_lacks " merge 1"

# --- /release-note-none: the command ----------------------------------

RELEASE_NOTE_NONE_PLUGIN="${PLUGINS_DIR}/release-note/release-note-none.plugin.sh"

begin_case "/release-note-none: is only available on pull requests"
export ISSUE_KIND="issue"
stub_label_scripts
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 1
assert_out_has "[FAIL] This command is only available on pull requests"
log_empty

begin_case "/release-note-none: never mutates labels when the PR query fails"
export MOCK_GH_FAIL=1
stub_label_scripts
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 1
assert_out_has "[FAIL] Failed to get the pull request."
log_lacks "stub"

begin_case "/release-note-none: a note in the body takes precedence over the command"
stub_label_scripts
mkpr "${NOTE_BODY}" "${NEEDED_LABEL}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 1
assert_out_has "takes precedence over \`/release-note-none\`"
log_lacks "stub"

begin_case "/release-note-none: labels a PR with an empty block release-note-none"
stub_label_scripts
mkpr "${EMPTY_BODY}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"
log_lacks "stub remove-labels.sh"
log_lacks "stub check-auto-merge.sh"

begin_case "/release-note-none: agrees with a NONE block in the body"
stub_label_scripts
mkpr "${NONE_BODY}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"

begin_case "/release-note-none: works when the body has no block at all"
stub_label_scripts
mkpr "Just a description."
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"

begin_case "/release-note-none: is idempotent when the label is already there"
stub_label_scripts
mkpr "${EMPTY_BODY}" "${NONE_LABEL}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_lacks "stub"

begin_case "/release-note-none: swaps a stale release-note label for release-note-none"
stub_label_scripts
mkpr "${EMPTY_BODY}" "${RELEASE_NOTE_LABEL}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"
log_has_line "stub remove-labels.sh ${RELEASE_NOTE_LABEL}"
log_lacks "stub check-auto-merge.sh"

begin_case "/release-note-none: clears the needed label without evaluating auto-merge"
stub_label_scripts
mkpr "${EMPTY_BODY}" "${NEEDED_LABEL}"
run "${RELEASE_NOTE_NONE_PLUGIN}"
assert_status 0
log_has_line "stub add-labels.sh ${NONE_LABEL}"
log_has_line "stub remove-labels.sh ${NEEDED_LABEL}"
log_lacks "stub check-auto-merge.sh"

# --- ensure-labels.sh: the label creation allowlist --------------------

begin_case "ensure-labels.sh: creates a well-known label with its color and description"
mkrepolabels
run ensure-labels.sh lgtm
assert_status 0
assert_out_has "Create label lgtm in wzshiming/example"
log_has "label -R wzshiming/example create lgtm --color 15dd18"
log_has "Looks good to me"

begin_case "ensure-labels.sh: refuses to create a label not in the allowlist"
mkrepolabels
run ensure-labels.sh totally-bogus
assert_status 0
assert_out_has "[SKIP] Label \`totally-bogus\` is not listed in LABELS, not creating it."
log_lacks " create "

begin_case "ensure-labels.sh: an exact LABELS entry allows the label"
export LABELS="language/go"
mkrepolabels
run ensure-labels.sh language/go
assert_status 0
log_has "create language/go --color ededed"

begin_case "ensure-labels.sh: a LABELS prefix entry allows the whole prefix"
export LABELS="language/"
mkrepolabels
run ensure-labels.sh language/rust
assert_status 0
log_has "create language/rust"

begin_case "ensure-labels.sh: a prefix entry does not allow the bare prefix name"
export LABELS="language/"
mkrepolabels
run ensure-labels.sh language
assert_status 0
assert_out_has "[SKIP] Label \`language\`"
log_lacks " create "

begin_case "ensure-labels.sh: leaves existing labels alone"
mkrepolabels lgtm approved
run ensure-labels.sh lgtm
assert_status 0
assert_out_lacks "Create label"
log_lacks " create "

begin_case "ensure-labels.sh: does nothing without arguments"
run ensure-labels.sh
assert_status 0
log_empty

begin_case "ensure-labels.sh: a mixed batch creates, skips and rejects per label"
export LABELS="custom-label"
mkrepolabels approved
run ensure-labels.sh approved lgtm custom-label bogus
assert_status 0
log_has "create lgtm"
log_has "create custom-label"
log_lacks "create approved"
log_lacks "create bogus"
assert_out_has "[SKIP] Label \`bogus\`"

# --- entrypoint.sh: the TYPE=edited dispatch ---------------------------

begin_case "entrypoint.sh: TYPE=edited syncs the wip and release-note labels"
export TYPE="edited"
export RELEASE_NOTE_REQUIRED=1
mkwip false "Fix the fonts"
mkpr "${NOTE_BODY}"
mklabels
run "${ENTRYPOINT}"
assert_status 0
assert_out_has "PR edited, syncing work-in-progress label"
log_has "view 1 --json isDraft,title,labels"
log_has "view 1 --json body,labels"
log_has_line "gh pr -R wzshiming/example edit 1 --add-label ${RELEASE_NOTE_LABEL}"

begin_case "entrypoint.sh: TYPE=edited leaves release notes alone when the gate is off"
export TYPE="edited"
mkwip false "Fix the fonts"
mkpr "${NOTE_BODY}"
mklabels
run "${ENTRYPOINT}"
assert_status 0
log_has "view 1 --json isDraft,title,labels"
log_lacks "--json body,labels"
log_lacks "edit"

begin_case "entrypoint.sh: TYPE=edited on an issue makes no calls at all"
export TYPE="edited"
export ISSUE_KIND="issue"
export RELEASE_NOTE_REQUIRED=1
run "${ENTRYPOINT}"
assert_status 0
log_empty

begin_case "entrypoint.sh: refuses to run without LOGIN"
export LOGIN=""
run "${ENTRYPOINT}"
assert_status 1
assert_out_is "No login specified"
log_empty

begin_case "entrypoint.sh: refuses to run without ISSUE_KIND"
export ISSUE_KIND=""
run "${ENTRYPOINT}"
assert_status 1
assert_out_is "No issue kind specified"
log_empty

begin_case "entrypoint.sh: refuses to run without ISSUE_NUMBER"
export ISSUE_NUMBER=""
run "${ENTRYPOINT}"
assert_status 1
assert_out_is "No issue number specified"
log_empty

begin_case "entrypoint.sh: refuses to run without GH_REPOSITORY"
export GH_REPOSITORY=""
run "${ENTRYPOINT}"
assert_status 1
assert_out_is "No repository specified"
log_empty

begin_case "entrypoint.sh: refuses to run without TYPE"
export TYPE=""
run "${ENTRYPOINT}"
assert_status 1
assert_out_is "No type"
log_empty
