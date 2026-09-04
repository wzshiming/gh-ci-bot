#!/usr/bin/env bash

IFS=","

action="${1:-}"

default_merge_method="${DEFAULT_MERGE_METHOD:-merge}"
method="${action:-${default_merge_method}}"

args=""

if [[ "${method}" == "merge" || "${method}" == "" ]]; then
  args="--merge"
elif [[ "${method}" == "rebase" ]]; then
  args="--rebase"
elif [[ "${method}" == "squash" ]]; then
  args="--squash"
else
  echo "[FAIL] Invalid merge method: \`${method}\`. Supported methods are: \`merge\`, \`rebase\`, or \`squash\`. Use \`DEFAULT_MERGE_METHOD\` to set the default."
  exit 1
fi

# Fail closed: never merge without having seen the labels.
if ! blocking_labels="$(gh pr -R "${GH_REPOSITORY}" view "${ISSUE_NUMBER}" --json labels --jq '[.labels[].name | select(. == "do-not-merge" or startswith("do-not-merge/") or . == "dco-signoff: no")] | join("`, `")')"; then
  echo "[FAIL] Failed to check for blocking labels, not merging."
  exit 1
fi
if [[ -n "${blocking_labels}" ]]; then
  echo "[FAIL] This PR cannot be merged because it has the following blocking label(s): \`${blocking_labels}\`."
  exit 1
fi

echo "PR ${GH_REPOSITORY}#${ISSUE_NUMBER} merge by ${LOGIN}"

# try_merge runs gh merge, printing its output and keeping the error of the
# last failed attempt for the [FAIL] reply.
merge_error=""
function try_merge() {
  local out
  if out="$(gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" merge "${ISSUE_NUMBER}" "$@" 2>&1)"; then
    [[ -n "${out}" ]] && echo "${out}"
    return 0
  fi
  [[ -n "${out}" ]] && echo "${out}"
  merge_error="$(echo "${out}" | tr '\n' ' ' | sed 's/  */ /g')"
  return 1
}

if ! try_merge "${args}"; then
  hint="$(gh api --paginate "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/files" --jq '.[].filename' | explain-workflows-permission.sh)"
  if [[ -n "${hint}" ]]; then
    # GitHub would never complete an auto-merge the token cannot perform.
    echo "[FAIL] Failed to merge the PR: ${merge_error:-unknown error}"
    echo "${hint}"
  # A direct merge fails when required checks are still pending; fall back
  # to enabling auto-merge so GitHub merges once they pass.
  elif ! try_merge --auto "${args}"; then
    echo "[FAIL] Failed to merge the PR: ${merge_error:-unknown error}"
  fi
fi
