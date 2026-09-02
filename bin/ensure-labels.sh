#!/usr/bin/env bash

# ensure-labels.sh - Make sure the given labels exist in the repository,
# creating any missing ones with a well-known color and description so
# that labels no longer need to be created manually in advance.
#
# Colors and descriptions are synchronized with prow's label definitions:
# https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.yaml
# Labels not defined by prow fall back to GitHub's defaults.
#
# Which labels are allowed to be created is controlled by the LABELS
# environment variable, a list of entries, one per line. Each entry is
# either an exact label name, or a prefix ending in a slash (e.g. kind/)
# which allows any label with that prefix. Labels not matching any entry
# are never created, so arbitrary labels (e.g. typos in /label commands)
# do not pollute the repository. LABELS is merged with the built-in
# default list of well-known prow and GitHub labels below, so entries in
# LABELS are additions to the defaults.
#
# Usage:
#   ensure-labels.sh <label>...

if [[ "${#}" -eq 0 ]]; then
  exit 0
fi

DEFAULT_LABELS="$(
  cat <<'EOF'
lgtm
approved
do-not-merge
do-not-merge/hold
do-not-merge/work-in-progress
do-not-merge/release-note-label-needed
do-not-merge/needs-kind
kind/api-change
kind/bug
kind/cleanup
kind/deprecation
kind/documentation
kind/failing-test
kind/feature
kind/flake
kind/regression
kind/support
needs-kind
needs-ok-to-test
needs-sig
needs-triage
ok-to-test
priority/awaiting-more-evidence
priority/backlog
priority/critical-urgent
priority/important-longterm
priority/important-soon
release-note
release-note-none
size/XS
size/S
size/M
size/L
size/XL
size/XXL
triage/accepted
triage/duplicate
triage/needs-information
triage/not-reproducible
triage/unresolved
bug
documentation
duplicate
enhancement
good first issue
help wanted
invalid
question
wontfix
EOF
)"

LABELS="${DEFAULT_LABELS}
${LABELS:-}"

# label_allowed checks whether a label matches an entry in LABELS and is
# thus allowed to be created. Entries ending in a slash (e.g. kind/) are
# prefixes matching any label starting with them; other entries match the
# label name exactly.
function label_allowed() {
  while IFS= read -r entry; do
    if [[ -z "${entry}" ]]; then
      continue
    fi
    if [[ "${entry}" == */ ]]; then
      if [[ "${1}" == "${entry}"?* ]]; then
        return 0
      fi
    elif [[ "${1}" == "${entry}" ]]; then
      return 0
    fi
  done <<<"${LABELS}"
  return 1
}

# label_color prints the well-known color for a label, falling back to
# GitHub's default gray for labels without a dedicated color.
function label_color() {
  case "${1}" in
  lgtm)
    echo "15dd18"
    ;;
  approved)
    echo "0ffa16"
    ;;
  do-not-merge | do-not-merge/*)
    echo "e11d21"
    ;;
  kind/api-change | kind/bug | kind/deprecation | kind/failing-test | kind/regression)
    echo "e11d21"
    ;;
  kind/flake)
    echo "f7c6c7"
    ;;
  kind/support)
    echo "d455d0"
    ;;
  kind/*)
    echo "c7def8"
    ;;
  area/*)
    echo "0052cc"
    ;;
  committee/*)
    echo "c0ff4a"
    ;;
  sig/* | wg/*)
    echo "d2b48c"
    ;;
  needs-ok-to-test)
    echo "b60205"
    ;;
  ok-to-test)
    echo "15dd18"
    ;;
  priority/awaiting-more-evidence)
    echo "fef2c0"
    ;;
  priority/backlog)
    echo "fbca04"
    ;;
  priority/critical-urgent)
    echo "e11d21"
    ;;
  priority/important-longterm | priority/important-soon)
    echo "eb6420"
    ;;
  release-note | release-note-none)
    echo "c2e0c6"
    ;;
  size/XS)
    echo "009900"
    ;;
  size/S)
    echo "77bb00"
    ;;
  size/M)
    echo "eebb00"
    ;;
  size/L)
    echo "ee9900"
    ;;
  size/XL)
    echo "ee5500"
    ;;
  size/XXL)
    echo "ee0000"
    ;;
  triage/accepted)
    echo "8fc951"
    ;;
  triage/*)
    echo "d455d0"
    ;;
  bug)
    echo "d73a4a"
    ;;
  documentation)
    echo "0075ca"
    ;;
  duplicate)
    echo "cfd3d7"
    ;;
  enhancement)
    echo "a2eeef"
    ;;
  "good first issue")
    echo "7057ff"
    ;;
  "help wanted")
    echo "006b75"
    ;;
  invalid)
    echo "e4e669"
    ;;
  question)
    echo "d876e3"
    ;;
  wontfix)
    echo "ffffff"
    ;;
  *)
    echo "ededed"
    ;;
  esac
}

# label_description prints the well-known description for a label,
# falling back to an empty description.
function label_description() {
  case "${1}" in
  lgtm)
    echo "\"Looks good to me\", indicates that a PR is ready to be merged."
    ;;
  approved)
    echo "Indicates a PR has been approved by an approver from all required OWNERS files."
    ;;
  do-not-merge)
    echo "Indicates that a PR should not merge. Label can only be manually applied/removed."
    ;;
  do-not-merge/hold)
    echo "Indicates that a PR should not merge because someone has issued a /hold command."
    ;;
  do-not-merge/work-in-progress)
    echo "Indicates that a PR should not merge because it is a work in progress."
    ;;
  do-not-merge/release-note-label-needed)
    echo "Indicates that a PR should not merge because it's missing one of the release note labels."
    ;;
  do-not-merge/needs-kind)
    echo "Indicates a PR lacks a \`kind/foo\` label and requires one."
    ;;
  do-not-merge/*)
    echo "Indicates that a PR should not merge."
    ;;
  kind/api-change)
    echo "Categorizes issue or PR as related to adding, removing, or otherwise changing an API"
    ;;
  kind/bug)
    echo "Categorizes issue or PR as related to a bug."
    ;;
  kind/cleanup)
    echo "Categorizes issue or PR as related to cleaning up code, process, or technical debt."
    ;;
  kind/deprecation)
    echo "Categorizes issue or PR as related to a feature/enhancement marked for deprecation."
    ;;
  kind/documentation)
    echo "Categorizes issue or PR as related to documentation."
    ;;
  kind/failing-test)
    echo "Categorizes issue or PR as related to a consistently or frequently failing test."
    ;;
  kind/feature)
    echo "Categorizes issue or PR as related to a new feature."
    ;;
  kind/flake)
    echo "Categorizes issue or PR as related to a flaky test."
    ;;
  kind/regression)
    echo "Categorizes issue or PR as related to a regression from a prior release."
    ;;
  kind/support)
    echo "Categorizes issue or PR as a support question."
    ;;
  kind/*)
    echo "Categorizes issue or PR as related to ${1#kind/}."
    ;;
  area/*)
    echo "Categorizes an issue or PR as related to ${1#area/}."
    ;;
  committee/*)
    echo "Denotes an issue or PR intended to be handled by the ${1#committee/} committee."
    ;;
  sig/*)
    echo "Categorizes an issue or PR as relevant to SIG ${1#sig/}."
    ;;
  wg/*)
    echo "Categorizes an issue or PR as relevant to WG ${1#wg/}."
    ;;
  needs-kind)
    echo "Indicates an issue or PR lacks a \`kind/foo\` label and requires one."
    ;;
  needs-ok-to-test)
    echo "Indicates a PR that requires an org member to verify it is safe to test."
    ;;
  needs-*)
    echo "Indicates an issue or PR lacks a \`${1#needs-}/foo\` label and requires one."
    ;;
  ok-to-test)
    echo "Indicates a non-member PR verified by an org member that is safe to test."
    ;;
  priority/awaiting-more-evidence)
    echo "Lowest priority. Possibly useful, but not yet enough support to actually get it done."
    ;;
  priority/backlog)
    echo "Higher priority than priority/awaiting-more-evidence."
    ;;
  priority/critical-urgent)
    echo "Highest priority. Must be actively worked on as someone's top priority right now."
    ;;
  priority/important-longterm)
    echo "Important over the long term, but may not be staffed and/or may need multiple releases to complete."
    ;;
  priority/important-soon)
    echo "Must be staffed and worked on either currently, or very soon, ideally in time for the next release."
    ;;
  release-note)
    echo "Denotes a PR that will be considered when it comes time to generate release notes."
    ;;
  release-note-none)
    echo "Denotes a PR that doesn't merit a release note."
    ;;
  size/XS)
    echo "Denotes a PR that changes 0-9 lines."
    ;;
  size/S)
    echo "Denotes a PR that changes 10-29 lines."
    ;;
  size/M)
    echo "Denotes a PR that changes 30-99 lines."
    ;;
  size/L)
    echo "Denotes a PR that changes 100-499 lines."
    ;;
  size/XL)
    echo "Denotes a PR that changes 500-999 lines."
    ;;
  size/XXL)
    echo "Denotes a PR that changes 1000+ lines."
    ;;
  triage/accepted)
    echo "Indicates an issue or PR is ready to be actively worked on."
    ;;
  triage/duplicate)
    echo "Indicates an issue is a duplicate of other open issue."
    ;;
  triage/needs-information)
    echo "Indicates an issue needs more information in order to work on it."
    ;;
  triage/not-reproducible)
    echo "Indicates an issue can not be reproduced as described."
    ;;
  triage/unresolved)
    echo "Indicates an issue that can not or will not be resolved."
    ;;
  bug)
    echo "Something isn't working"
    ;;
  documentation)
    echo "Improvements or additions to documentation"
    ;;
  duplicate)
    echo "This issue or pull request already exists"
    ;;
  enhancement)
    echo "New feature or request"
    ;;
  "good first issue")
    echo "Denotes an issue ready for a new contributor, according to the \"help wanted\" guidelines."
    ;;
  "help wanted")
    echo "Denotes an issue that needs help from a contributor. Must meet \"help wanted\" guidelines."
    ;;
  invalid)
    echo "This doesn't seem right"
    ;;
  question)
    echo "Further information is requested"
    ;;
  wontfix)
    echo "This will not be worked on"
    ;;
  *)
    echo ""
    ;;
  esac
}

existing="$(gh label -R "${GH_REPOSITORY}" list --limit 1000 --json name --jq '.[].name')"

for label in "${@}"; do
  if [[ -z "${label}" ]]; then
    continue
  fi
  if grep -qxF "${label}" <<<"${existing}"; then
    continue
  fi
  if ! label_allowed "${label}"; then
    echo "[SKIP] Label \`${label//\@/}\` is not listed in LABELS, not creating it."
    continue
  fi
  echo "Create label ${label//\@/} in ${GH_REPOSITORY}"
  gh label -R "${GH_REPOSITORY}" create "${label}" --color "$(label_color "${label}")" --description "$(label_description "${label}")" ||
    echo "[FAIL] Failed to create label \`${label//\@/}\`."
done
