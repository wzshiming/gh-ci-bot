#!/usr/bin/env bash

# retitle plugin: edits the title and syncs the work-in-progress label;
# a failed edit is reported with [FAIL] and skips the label sync.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

RETITLE="${PLUGINS_DIR}/retitle/retitle.plugin.sh"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

begin_case "retitles the PR and syncs the wip label"
stub_label_scripts
# The PR as check-wip sees it after the edit: WIP label, non-WIP title.
mkwip false "Add a renderer" "do-not-merge/work-in-progress"
run "${RETITLE}" Add a renderer
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --title Add a renderer"
log_has_line "stub remove-labels.sh do-not-merge/work-in-progress"
log_lacks "stub check-auto-merge.sh"

begin_case "replies [FAIL] and skips the wip sync when the edit fails"
stub_label_scripts
export MOCK_GH_FAIL=1
run "${RETITLE}" Add a renderer
assert_status 1
assert_out_has "[FAIL] Failed to retitle."
log_lacks "--json isDraft,title,labels"
log_lacks "stub"
