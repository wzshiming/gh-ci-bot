#!/usr/bin/env bash

IFS=","

label="${*}"

if [[ -z "${label}" ]]; then
  echo "[FAIL] Missing required argument: label name."
  exit 1
fi

echo "Add label ${label//\@/} to ${GH_REPOSITORY}#${ISSUE_NUMBER}"
if ! gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-label "${label}"; then
  # Adding failed, likely because a label does not exist yet.
  # Create any missing labels listed in LABELS, then retry with only the
  # labels that exist so unknown labels are never created.
  read -r -a wanted <<<"${label}"
  ensure-labels.sh "${wanted[@]}"

  existing="$(gh label -R "${GH_REPOSITORY}" list --limit 1000 --json name --jq '.[].name')"
  labels=()
  for l in "${wanted[@]}"; do
    if [[ -z "${l}" ]]; then
      continue
    fi
    if grep -qxF "${l}" <<<"${existing}"; then
      labels+=("${l}")
    else
      echo "[FAIL] Label \`${l//\@/}\` does not exist."
    fi
  done

  if [[ "${#labels[@]}" -ne 0 ]]; then
    gh "${ISSUE_KIND}" -R "${GH_REPOSITORY}" edit "${ISSUE_NUMBER}" --add-label "${labels[*]}" ||
      echo "[FAIL] Failed to add label \`${labels[*]}\`."
  fi
fi
