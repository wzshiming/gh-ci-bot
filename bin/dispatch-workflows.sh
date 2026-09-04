#!/usr/bin/env bash

# dispatch-workflows.sh <created|synchronize|reopened> [head-branch]
# The default GITHUB_TOKEN starts no runs for the PRs the bot creates or
# pushes; only workflow_dispatch does. So this dispatches the bot's own
# workflow for the PR, and every workflow listed in DISPATCH_WORKFLOWS on the
# head branch (absent when the head is in a fork, which cannot be targeted).
# `*` lists the head branch's workflows that run on pull_request and have the
# workflow_dispatch trigger. PATs and GitHub App tokens fire the real events,
# so other logins do nothing.

type="${1}"
head="${2:-}"

if [[ "$(bot-login.sh)" != "github-actions[bot]" ]]; then
  exit 0
fi

failed=0

if [[ -z "${GITHUB_WORKFLOW_REF:-}" ]]; then
  echo "Not running in GitHub Actions, not starting the bot's run for #${ISSUE_NUMBER}"
else
  own="${GITHUB_WORKFLOW_REF%@*}"
  own="${own##*/}"
  # No --ref: in review-comment runs GITHUB_REF_NAME is "<n>/merge"; gh's default branch is right.
  if ! out="$(gh workflow run "${own}" -R "${GH_REPOSITORY}" -f number="${ISSUE_NUMBER}" -f type="${type}" 2>&1)"; then
    echo "[FAIL] Failed to start the bot's run for #${ISSUE_NUMBER}: ${out//$'\n'/ }. Add the \`workflow_dispatch\` trigger and the \"PR Dispatched\" step from gh-ci-bot's examples/ci-bot.yml to \`${own}\`."
    failed=1
  fi
fi

mapfile -t workflows < <(grep -v '^[[:space:]]*$' <<<"${DISPATCH_WORKFLOWS:-}")

if [[ "${#workflows[@]}" -ne 0 ]]; then
  if [[ -z "${head}" ]]; then
    list="$(printf '%s, ' "${workflows[@]}")"
    list="${list%, }"
    if [[ "${list}" == "*" ]]; then
      list="its workflows"
    fi
    echo "[FAIL] The head branch of #${ISSUE_NUMBER} is in a fork, so ${list} cannot be started with workflow_dispatch; push to the branch or close and reopen the PR to run them."
    failed=1
  else
    if [[ "${workflows[*]}" == "*" ]]; then
      if ! paths="$(gh api --paginate "/repos/${GH_REPOSITORY}/actions/workflows" --jq '.workflows[] | select(.state == "active") | .path | select(startswith(".github/workflows/"))' 2>&1)"; then
        echo "[FAIL] Failed to list the workflows of ${GH_REPOSITORY}: ${paths//$'\n'/ }"
        failed=1
        paths=""
      fi
      workflows=()
      while read -r path; do
        if [[ -z "${path}" || "${path##*/}" == "${own:-}" ]]; then
          continue
        fi
        # Stale list entries and files the branch does not have come back 404.
        if ! content="$(gh api -H 'Accept: application/vnd.github.raw+json' "/repos/${GH_REPOSITORY}/contents/${path}?ref=${head}" 2>/dev/null)"; then
          echo "Skipping ${path}: not on ${head}"
          continue
        fi
        # Only the on: block counts, not e.g. an `if: github.event_name == 'pull_request'`.
        on="$(awk '/^"?on"?:/ {p=1; print; next} p && /^[^[:space:]#]/ {exit} p' <<<"${content}")"
        if grep -Eq '(^|[^[:alnum:]_])pull_request([^[:alnum:]_]|$)' <<<"${on}" && grep -Eq '(^|[^[:alnum:]_])workflow_dispatch([^[:alnum:]_]|$)' <<<"${on}"; then
          workflows+=("${path##*/}")
        fi
      done <<<"${paths}"
    fi
    for wf in "${workflows[@]}"; do
      if ! out="$(gh workflow run "${wf}" -R "${GH_REPOSITORY}" --ref "${head}" 2>&1)"; then
        echo "[FAIL] Failed to start ${wf} on ${head}: ${out//$'\n'/ }"
        failed=1
      fi
    done
  fi
fi

exit "${failed}"
