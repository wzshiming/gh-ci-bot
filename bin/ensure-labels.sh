#!/usr/bin/env bash

# ensure-labels.sh - Make sure the given labels exist in the repository,
# creating any missing ones with a well-known color and description so
# that labels no longer need to be created manually in advance.
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
  kind/bug)
    echo "e11d21"
    ;;
  kind/*)
    echo "c7def8"
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
    echo "008672"
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
    echo "Indicates that a PR is ready to be merged."
    ;;
  approved)
    echo "Indicates a PR has been approved by owners of all changed areas."
    ;;
  do-not-merge/work-in-progress)
    echo "Indicates that a PR should not merge because it is a work in progress."
    ;;
  do-not-merge | do-not-merge/*)
    echo "Indicates that a PR should not merge."
    ;;
  kind/*)
    echo "Categorizes issue or PR as related to ${1#kind/}."
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
    echo "Good for newcomers"
    ;;
  "help wanted")
    echo "Extra attention is needed"
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
