#!/usr/bin/env bash

# check-wip.sh: the do-not-merge/work-in-progress label follows the PR's
# draft state and title, mirroring prow's wip plugin.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

WIP_LABEL="do-not-merge/work-in-progress"

function stub_label_scripts() {
    stub add-labels.sh
    stub remove-labels.sh
    stub check-auto-merge.sh
}

begin_case "labels a draft PR"
stub_label_scripts
mkwip true "Add a renderer"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "leaves an already labeled draft alone"
stub_label_scripts
mkwip true "Add a renderer" "${WIP_LABEL}"
run check-wip.sh
assert_status 0
log_has "view 1 --json isDraft,title,labels"
log_lacks "stub"

begin_case "labels a PR titled 'WIP: ...'"
stub_label_scripts
mkwip false "WIP: add a renderer"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"

begin_case "labels a PR titled '[WIP] ...'"
stub_label_scripts
mkwip false "[WIP] add a renderer"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"

begin_case "the WIP title prefix is case-insensitive"
stub_label_scripts
mkwip false "wip: add a renderer"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"

begin_case "labels a PR titled exactly 'WIP'"
stub_label_scripts
mkwip false "WIP"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"

begin_case "a word merely starting with WIP is not work in progress"
stub_label_scripts
mkwip false "WIPE the cache on restart"
run check-wip.sh
assert_status 0
log_lacks "stub"

begin_case "WIP not at the start of the title is not work in progress"
stub_label_scripts
mkwip false "Fix WIP handling" "${WIP_LABEL}"
run check-wip.sh
assert_status 0
log_has_line "stub remove-labels.sh ${WIP_LABEL}"
log_lacks "stub check-auto-merge.sh"

begin_case "unlabels a PR that is no longer a draft without evaluating auto-merge"
stub_label_scripts
mkwip false "Add a renderer" "${WIP_LABEL}" "kind/feature"
run check-wip.sh
assert_status 0
log_has_line "stub remove-labels.sh ${WIP_LABEL}"
log_lacks "stub check-auto-merge.sh"
log_lacks "stub add-labels.sh"

begin_case "leaves a ready unlabeled PR alone"
stub_label_scripts
mkwip false "Add a renderer" "kind/feature"
run check-wip.sh
assert_status 0
log_has "view 1 --json isDraft,title,labels"
log_lacks "stub"

begin_case "a label merely prefixed with the WIP label does not count: draft still gets it"
stub_label_scripts
mkwip true "Add a renderer" "${WIP_LABEL}-docs"
run check-wip.sh
assert_status 0
log_has_line "stub add-labels.sh ${WIP_LABEL}"
log_lacks "stub remove-labels.sh"

begin_case "a label merely prefixed with the WIP label does not count: ready PR is left alone"
stub_label_scripts
mkwip false "Add a renderer" "${WIP_LABEL}-docs"
run check-wip.sh
assert_status 0
log_has "view 1 --json isDraft,title,labels"
log_lacks "stub"

begin_case "does nothing for issues"
stub_label_scripts
export ISSUE_KIND="issue"
run check-wip.sh
assert_status 0
log_empty

begin_case "full stack: really removes the label via gh without evaluating auto-merge"
mkwip false "Add a renderer" "${WIP_LABEL}"
run check-wip.sh
assert_status 0
log_has_line "gh pr -R wzshiming/example edit 1 --remove-label ${WIP_LABEL}"
log_lacks "view 1 --json labels"
log_lacks " merge 1"
