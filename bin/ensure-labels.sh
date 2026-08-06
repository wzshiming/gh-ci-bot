#!/usr/bin/env bash

# ensure-labels.sh - Make sure the given labels exist in the repository,
# creating any missing ones that are defined in the LABELS environment
# variable, a YAML list of label definitions:
#   - name: area/network
#     color: 0052cc
#     description: Issues or PRs related to networking.
#   - priority/critical
# Entries given as plain strings use GitHub's default gray color and an
# empty description. Labels not defined in LABELS are never created, so
# arbitrary labels (e.g. typos in /label commands) do not pollute the
# repository.
#
# When LABELS is not set, it defaults to the definitions below: the labels
# synchronized with prow's label definitions
# https://github.com/kubernetes/test-infra/blob/master/label_sync/labels.yaml
# plus GitHub's built-in labels. Setting LABELS replaces the default list.
#
# Usage:
#   ensure-labels.sh <label>...

if [[ "${#}" -eq 0 ]]; then
  exit 0
fi

DEFAULT_LABELS="$(
  cat <<'EOF'
- name: lgtm
  color: "15dd18"
  description: '"Looks good to me", indicates that a PR is ready to be merged.'
- name: approved
  color: "0ffa16"
  description: Indicates a PR has been approved by an approver from all required OWNERS files.
- name: do-not-merge
  color: e11d21
  description: Indicates that a PR should not merge. Label can only be manually applied/removed.
- name: do-not-merge/hold
  color: e11d21
  description: Indicates that a PR should not merge because someone has issued a /hold command.
- name: do-not-merge/work-in-progress
  color: e11d21
  description: Indicates that a PR should not merge because it is a work in progress.
- name: kind/api-change
  color: e11d21
  description: Categorizes issue or PR as related to adding, removing, or otherwise changing an API
- name: kind/bug
  color: e11d21
  description: Categorizes issue or PR as related to a bug.
- name: kind/cleanup
  color: c7def8
  description: Categorizes issue or PR as related to cleaning up code, process, or technical debt.
- name: kind/deprecation
  color: e11d21
  description: Categorizes issue or PR as related to a feature/enhancement marked for deprecation.
- name: kind/documentation
  color: c7def8
  description: Categorizes issue or PR as related to documentation.
- name: kind/failing-test
  color: e11d21
  description: Categorizes issue or PR as related to a consistently or frequently failing test.
- name: kind/feature
  color: c7def8
  description: Categorizes issue or PR as related to a new feature.
- name: kind/flake
  color: f7c6c7
  description: Categorizes issue or PR as related to a flaky test.
- name: kind/regression
  color: e11d21
  description: Categorizes issue or PR as related to a regression from a prior release.
- name: kind/support
  color: d455d0
  description: Categorizes issue or PR as a support question.
- name: needs-kind
  color: ededed
  description: Indicates an issue or PR lacks a `kind/foo` label and requires one.
- name: size/XS
  color: "009900"
  description: Denotes a PR that changes 0-9 lines.
- name: size/S
  color: 77bb00
  description: Denotes a PR that changes 10-29 lines.
- name: size/M
  color: eebb00
  description: Denotes a PR that changes 30-99 lines.
- name: size/L
  color: ee9900
  description: Denotes a PR that changes 100-499 lines.
- name: size/XL
  color: ee5500
  description: Denotes a PR that changes 500-999 lines.
- name: size/XXL
  color: ee0000
  description: Denotes a PR that changes 1000+ lines.
- name: bug
  color: d73a4a
  description: Something isn't working
- name: documentation
  color: 0075ca
  description: Improvements or additions to documentation
- name: duplicate
  color: cfd3d7
  description: This issue or pull request already exists
- name: enhancement
  color: a2eeef
  description: New feature or request
- name: good first issue
  color: 7057ff
  description: Denotes an issue ready for a new contributor, according to the "help wanted" guidelines.
- name: help wanted
  color: 006b75
  description: Denotes an issue that needs help from a contributor. Must meet "help wanted" guidelines.
- name: invalid
  color: e4e669
  description: This doesn't seem right
- name: question
  color: d876e3
  description: Further information is requested
- name: wontfix
  color: ffffff
  description: This will not be worked on
EOF
)"

LABELS="${LABELS-${DEFAULT_LABELS}}"

# label_color prints the color defined for a label in LABELS, falling back
# to GitHub's default gray for entries listed without a color. Prints
# nothing if the label is not defined.
function label_color() {
  _label="${1}" yq e '.[] | select((.name // .) == strenv(_label)) | .color // "ededed"' <<<"${LABELS}" 2>/dev/null | head -n 1
}

# label_description prints the description defined for a label in LABELS,
# falling back to an empty description.
function label_description() {
  _label="${1}" yq e '.[] | select((.name // .) == strenv(_label)) | .description // ""' <<<"${LABELS}" 2>/dev/null | head -n 1
}

existing="$(gh label -R "${GH_REPOSITORY}" list --limit 1000 --json name --jq '.[].name')"

for label in "${@}"; do
  if [[ -z "${label}" ]]; then
    continue
  fi
  if grep -qxF "${label}" <<<"${existing}"; then
    continue
  fi
  color="$(label_color "${label}")"
  if [[ -z "${color}" ]]; then
    echo "[SKIP] Label \`${label//\@/}\` is not defined in LABELS, not creating it."
    continue
  fi
  description="$(label_description "${label}")"
  echo "Create label ${label//\@/} in ${GH_REPOSITORY}"
  gh label -R "${GH_REPOSITORY}" create "${label}" --color "${color}" --description "${description}" ||
    echo "[FAIL] Failed to create label \`${label//\@/}\`."
done
