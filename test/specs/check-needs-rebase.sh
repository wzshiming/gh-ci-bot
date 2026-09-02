#!/usr/bin/env bash

# check-needs-rebase.sh: the needs-rebase label follows the PR's
# mergeability, mirroring prow's needs-rebase external plugin: conflicting
# PRs are labeled and asked to rebase, and the label and the stale rebase
# requests go away once the conflicts are resolved.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

NEEDS_REBASE_LABEL="needs-rebase"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub comment.sh
}

begin_case "does nothing unless NEEDS_REBASE is set"
stub_label_scripts
mkmergeable OPEN CONFLICTING
run check-needs-rebase.sh
assert_status 0
log_empty

begin_case "does nothing for issues"
export NEEDS_REBASE=1
export ISSUE_KIND="issue"
stub_label_scripts
run check-needs-rebase.sh
assert_status 0
log_empty

begin_case "never mutates labels when the PR query fails"
export NEEDS_REBASE=1
export MOCK_GH_FAIL=1
stub_label_scripts
run check-needs-rebase.sh
assert_status 0
assert_out_has "Failed to get the pull request"
log_has "view 1 --json mergeable,state,labels"
log_lacks "stub"

begin_case "labels a conflicting PR and asks the author to rebase"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable OPEN CONFLICTING "kind/bug"
run check-needs-rebase.sh
assert_status 0
log_has_line "stub add-labels.sh ${NEEDS_REBASE_LABEL}"
log_has "stub comment.sh @bob: PR needs rebase."
log_lacks "stub remove-labels.sh"

begin_case "does not ask again while the label is already there"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable OPEN CONFLICTING "${NEEDS_REBASE_LABEL}"
run check-needs-rebase.sh
assert_status 0
log_has "view 1 --json mergeable,state,labels"
log_lacks "stub"

begin_case "removes the label and prunes the stale rebase requests once mergeable"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable OPEN MERGEABLE "${NEEDS_REBASE_LABEL}" "kind/bug"
mkcomments \
    "mock-bot=@bob: PR needs rebase." \
    "alice=PR needs rebase." \
    "mock-bot=Approve status."
run check-needs-rebase.sh
assert_status 0
log_has_line "stub remove-labels.sh ${NEEDS_REBASE_LABEL}"
log_has_line "gh api /repos/wzshiming/example/issues/comments/1 --silent -X DELETE"
log_lacks "issues/comments/2"
log_lacks "issues/comments/3"
log_lacks "stub add-labels.sh"

begin_case "leaves a mergeable unlabeled PR alone"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable OPEN MERGEABLE "kind/bug"
run check-needs-rebase.sh
assert_status 0
log_has "view 1 --json mergeable,state,labels"
log_lacks "stub"
log_lacks "DELETE"

begin_case "retries while mergeability is UNKNOWN and acts on the settled state"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable OPEN UNKNOWN
cat >"${STUB_DIR}/sleep" <<'EOF'
#!/usr/bin/env bash
echo "stub sleep ${*}" >>"${MOCK_LOG}"
jq -n '{mergeable: "CONFLICTING", state: "OPEN", labels: []}' >"${MOCK_MERGEABLE_JSON}"
EOF
chmod +x "${STUB_DIR}/sleep"
run check-needs-rebase.sh
assert_status 0
log_has_line "stub sleep 5"
log_has_line "stub add-labels.sh ${NEEDS_REBASE_LABEL}"

begin_case "gives up without mutating when mergeability never settles"
export NEEDS_REBASE=1
stub_label_scripts
stub sleep
mkmergeable OPEN UNKNOWN
run check-needs-rebase.sh
assert_status 0
assert_out_has "not known yet, skipping the needs-rebase sync"
log_has_line "stub sleep 5"
log_lacks "stub add-labels.sh"
log_lacks "stub remove-labels.sh"
log_lacks "stub comment.sh"

begin_case "ignores closed PRs"
export NEEDS_REBASE=1
stub_label_scripts
mkmergeable CLOSED CONFLICTING
run check-needs-rebase.sh
assert_status 0
log_has "view 1 --json mergeable,state,labels"
log_lacks "stub"

begin_case "full stack: really labels and comments on a conflicting PR via gh"
export NEEDS_REBASE=1
mkmergeable OPEN CONFLICTING
run check-needs-rebase.sh
assert_status 0
log_has "gh pr -R wzshiming/example edit 1 --add-label ${NEEDS_REBASE_LABEL}"
log_has "comment 1 --body @bob: PR needs rebase."

begin_case "full stack: really removes the label via gh once mergeable"
export NEEDS_REBASE=1
mkmergeable OPEN MERGEABLE "${NEEDS_REBASE_LABEL}"
mkcomments "mock-bot=@bob: PR needs rebase."
run check-needs-rebase.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --remove-label ${NEEDS_REBASE_LABEL}"
log_has_line "gh api /repos/wzshiming/example/issues/comments/1 --silent -X DELETE"

# --- entrypoint.sh: the dispatch -----------------------------------------

begin_case "entrypoint.sh: TYPE=edited syncs the needs-rebase label when the gate is on"
export TYPE="edited"
export NEEDS_REBASE=1
mkwip false "Fix the fonts"
mkmergeable OPEN CONFLICTING
run "${ENTRYPOINT}"
assert_status 0
log_has "view 1 --json mergeable,state,labels"
log_has "gh pr -R wzshiming/example edit 1 --add-label ${NEEDS_REBASE_LABEL}"
log_has "comment 1 --body @bob: PR needs rebase."

begin_case "entrypoint.sh: TYPE=edited leaves mergeability alone when the gate is off"
export TYPE="edited"
mkwip false "Fix the fonts"
run "${ENTRYPOINT}"
assert_status 0
log_has "view 1 --json isDraft,title,labels"
log_lacks "--json mergeable,state,labels"
