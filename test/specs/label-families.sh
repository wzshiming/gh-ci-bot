#!/usr/bin/env bash

# label-families.sh: the prow-style prefixed label families - /kind, /sig,
# /area, /priority, /triage, /wg, /committee and their /remove-*
# counterparts - map command values to <family>/<value> labels, and
# ensure-labels.sh knows the well-known prow labels of the new families.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

# member <plugins...> grants alice the members tier with the given plugins.
function member() {
    export AUTHOR_ASSOCIATION="MEMBER"
    export MEMBERS_PLUGINS="${*}"
}

# family_case <family> <value> checks that /<family> <value> and
# /remove-<family> <value> add and remove the <family>/<value> label.
function family_case() {
    local family="${1}"
    local value="${2}"
    begin_case "/${family} and /remove-${family} map to the ${family}/ label family"
    member "label-${family}"
    export ISSUE_KIND="issue"
    export MESSAGE=$"/${family} ${value}"$'\n'"/remove-${family} ${value}"
    stub add-labels.sh
    stub remove-labels.sh
    run command.sh
    assert_status 0
    log_has_line "stub add-labels.sh ${family}/${value}"
    log_has_line "stub remove-labels.sh ${family}/${value}"
}

family_case kind feature
family_case sig node
family_case area api
family_case priority backlog
family_case triage accepted
family_case wg policy
family_case committee steering

begin_case "several values become several family labels"
member label-priority
export ISSUE_KIND="issue"
export MESSAGE="/priority backlog critical-urgent"
stub add-labels.sh
run command.sh
assert_status 0
log_has_line "stub add-labels.sh priority/backlog,priority/critical-urgent"

begin_case "family commands outside the granted tiers get a permission reply"
export ISSUE_KIND="issue"
export MESSAGE="/sig node"
stub add-labels.sh
run command.sh
assert_status 0
assert_out_has "[FAIL] You don't have permission to use the \`/sig\` command."
log_empty

begin_case "the standard prow priority and triage labels are created on demand"
mkrepolabels
run ensure-labels.sh priority/backlog priority/critical-urgent triage/accepted triage/unresolved
assert_status 0
log_has "create priority/backlog --color fbca04"
log_has "create priority/critical-urgent --color e11d21"
log_has "create triage/accepted --color 8fc951"
log_has "create triage/unresolved --color d455d0"

begin_case "sig/area/wg/committee labels are not created unless allowlisted"
mkrepolabels
run ensure-labels.sh sig/node area/api wg/policy committee/steering
assert_status 0
assert_out_has "[SKIP] Label \`sig/node\` is not listed in LABELS, not creating it."
log_lacks "create"

begin_case "LABELS prefix entries allow creating family labels with prow colors"
export LABELS=$'sig/\narea/\nwg/\ncommittee/'
mkrepolabels
run ensure-labels.sh sig/node area/api wg/policy committee/steering
assert_status 0
log_has "create sig/node --color d2b48c"
log_has "create area/api --color 0052cc"
log_has "create wg/policy --color d2b48c"
log_has "create committee/steering --color c0ff4a"
