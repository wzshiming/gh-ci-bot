#!/usr/bin/env bash

# ensure-labels.sh - Make sure the given labels exist in the repository,
# creating any missing ones with a well-known color and description so
# that labels no longer need to be created manually in advance.
#
# Colors and descriptions are synchronized with prow's label definitions:
# https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.yaml
# Labels not defined by prow fall back to GitHub's defaults.
#
# Usage:
#   ensure-labels.sh <label>...

if [[ "${#}" -eq 0 ]]; then
  exit 0
fi

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
  lifecycle/frozen)
    echo "d3e2f0"
    ;;
  lifecycle/stale)
    echo "795548"
    ;;
  lifecycle/rotten)
    echo "604460"
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
  lifecycle/frozen)
    echo "Indicates that an issue or PR should not be auto-closed due to staleness."
    ;;
  lifecycle/stale)
    echo "Denotes an issue or PR has remained open with no activity and has become stale."
    ;;
  lifecycle/rotten)
    echo "Denotes an issue or PR that has aged beyond stale and will be auto-closed."
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
  echo "Create label ${label//\@/} in ${GH_REPOSITORY}"
  gh label -R "${GH_REPOSITORY}" create "${label}" --color "$(label_color "${label}")" --description "$(label_description "${label}")" ||
    echo "[FAIL] Failed to create label \`${label//\@/}\`."
done
