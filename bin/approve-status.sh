#!/usr/bin/env bash

# approve-status.sh - Maintain per-area approval state in a PR comment.
#
# The state is stored in a single bot comment. The comment starts with a
# hidden machine-readable block:
#   <!-- ci-bot-approve-status
#   <area> <approver>...
#   -->
# followed by a human-readable summary table. An area is approved when at
# least one of its approvers has approved it. The PR gets the "approved"
# label once every changed area is approved.
#
# Usage:
#   approve-status.sh approve <login>    Record approval for the areas <login> owns
#   approve-status.sh unapprove <login>  Remove all approvals of <login>
#   approve-status.sh sync               Recompute state against the current change set
#
# The "approved" label is kept in sync with the state after every command,
# mirroring prow's approve plugin: approvals are sticky across new commits.
#
# Requires OWNERS_AREA_APPROVERS (exported by owners.sh) for all commands.
# If AUTHOR is set, areas owned by the PR author are approved by default
# (prow's implicit self-approval).

STATUS_MARKER="<!-- ci-bot-approve-status"

function find_status_comment() {
    local bot_login
    bot_login="$(bot-login.sh)"
    gh api --paginate "/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/comments" |
        jq -r "[.[] | select(.user.login == \"${bot_login}\") | select(.body | startswith(\"${STATUS_MARKER}\"))] | first | .id // empty"
}

# get_status_state prints the state lines ("<area> <approver>...") stored
# in the comment with the given id.
function get_status_state() {
    local id="$1"
    gh api "/repos/${GH_REPOSITORY}/issues/comments/${id}" --jq '.body' |
        sed -n "/^${STATUS_MARKER}$/,/^-->$/p" | sed '1d;$d'
}

# state_approved_for prints the approvers recorded in the state for an area.
function state_approved_for() {
    local state="$1"
    local area="$2"
    echo "${state}" | awk -v a="${area}" '$1 == a { $1 = ""; print substr($0, 2) }'
}

# render_body renders the full comment body from the state lines.
# OWNERS_AREA_APPROVERS provides the approver list of each area.
function render_body() {
    local state="$1"

    local all_approved=true
    local approved_users=""
    local area approved
    while read -r area approved; do
        [[ -z "${area}" ]] && continue
        if [[ -z "${approved}" ]]; then
            all_approved=false
        else
            approved_users="${approved_users} ${approved}"
        fi
    done <<<"${state}"
    approved_users="$(echo ${approved_users} | tr ' ' '\n' | sed '/^$/d' | sort -u)"

    local server_url="${GITHUB_SERVER_URL:-https://github.com}"
    branch="${branch:-$(gh api /repos/${GH_REPOSITORY} | jq -r '.default_branch')}"

    echo "${STATUS_MARKER}"
    echo "${state}"
    echo "-->"
    if [[ "${all_approved}" == "true" ]]; then
        echo "[APPROVALNOTIFIER] This PR is **APPROVED**"
    else
        echo "[APPROVALNOTIFIER] This PR is **NOT APPROVED**"
    fi
    echo

    if [[ -n "${approved_users}" ]]; then
        local names=""
        local u
        while read -r u; do
            if [[ "${u}" == "${AUTHOR:-}" ]]; then
                names="${names}, *<a href=\"${server_url}/${u}\" title=\"Author self-approved\">${u}</a>*"
            else
                names="${names}, *<a href=\"${server_url}/${u}\" title=\"Approved\">${u}</a>*"
            fi
        done <<<"${approved_users}"
        echo "This pull-request has been approved by: ${names#, }"
        echo
    fi

    if [[ "${all_approved}" == "true" ]]; then
        echo "<details>"
    else
        echo "<details open>"
    fi
    echo "Needs approval from an approver in each of these areas:"
    echo
    local path link approvers
    while read -r area approved; do
        [[ -z "${area}" ]] && continue
        if [[ "${area}" == "." ]]; then
            path="OWNERS"
        else
            path="${area}/OWNERS"
        fi
        link="${server_url}/${GH_REPOSITORY}/blob/${branch}/${path}"
        approvers="$(echo "${OWNERS_AREA_APPROVERS}" | awk -v a="${area}" '$1 == a { $1 = ""; print substr($0, 2) }')"
        if [[ -n "${approved}" ]]; then
            echo "- ~~[${path}](${link})~~ [${approvers// /,}]"
        else
            echo "- [${path}](${link}) [${approvers// /,}]"
        fi
    done <<<"${state}"
    echo
    echo "Approvers can indicate their approval by writing \`/approve\` in a comment"
    echo "Approvers can cancel approval by writing \`/approve cancel\` in a comment"
    echo "</details>"

    if [[ "${all_approved}" != "true" ]]; then
        local suggested=""
        local u
        while read -r area approved; do
            [[ -z "${area}" || -n "${approved}" ]] && continue
            approvers="$(echo "${OWNERS_AREA_APPROVERS}" | awk -v a="${area}" '$1 == a { $1 = ""; print substr($0, 2) }')"
            # Skip areas already covered by a suggested approver
            for u in ${approvers}; do
                if echo "${suggested}" | tr ' ' '\n' | grep -qxF "${u}"; then
                    continue 2
                fi
            done
            for u in ${approvers}; do
                if [[ "${u}" != "${AUTHOR:-}" ]]; then
                    suggested="${suggested} ${u}"
                    break
                fi
            done
        done <<<"${state}"
        suggested="${suggested# }"
        if [[ -n "${suggested}" ]]; then
            echo
            echo "We suggest the following additional approvers: **${suggested// /**, **}**"
            echo
            echo "You can assign the PR to them by writing \`/assign @${suggested// / @}\` in a comment."
        fi
    fi
}

# save_status_comment creates or updates the status comment.
function save_status_comment() {
    local state="$1"
    local body
    body="$(render_body "${state}")"
    local id
    id="$(find_status_comment)"
    if [[ -n "${id}" ]]; then
        gh api --silent -X PATCH "/repos/${GH_REPOSITORY}/issues/comments/${id}" -f body="${body}"
    else
        gh api --silent -X POST "/repos/${GH_REPOSITORY}/issues/${ISSUE_NUMBER}/comments" -f body="${body}"
    fi
}

# build_state merges the stored state with the current areas: stale areas
# are dropped. Areas seen for the first time start with no approvals,
# except that the PR author pre-approves the areas they own.
function build_state() {
    local old_state="$1"
    local state=""
    local area approvers approved
    while read -r area approvers; do
        [[ -z "${area}" ]] && continue
        if echo "${old_state}" | awk -v a="${area}" '$1 == a { found = 1 } END { exit !found }'; then
            approved="$(state_approved_for "${old_state}" "${area}")"
        elif [[ -n "${AUTHOR:-}" ]] && echo "${approvers}" | tr ' ' '\n' | grep -qxF "${AUTHOR}"; then
            approved="${AUTHOR}"
            echo "Area '${area}' approved by default: PR author ${AUTHOR} is an approver" >&2
        else
            approved=""
        fi
        state="${state}${area} ${approved}
"
    done <<<"${OWNERS_AREA_APPROVERS}"
    echo "${state}" | sed '/^$/d' | sed 's/ *$//'
}

# state_all_approved succeeds when every area has at least one approval.
function state_all_approved() {
    echo "$1" | awk 'NF < 2 { exit 1 }'
}

# reconcile_label keeps the "approved" label in sync with the state.
function reconcile_label() {
    local all_approved="$1"
    if [[ "${all_approved}" == "true" ]]; then
        add-labels.sh approved
    else
        remove-labels.sh approved
    fi
}

function cmd_approve() {
    local login="$1"

    if [[ -z "${OWNERS_AREA_APPROVERS}" ]]; then
        # No OWNERS areas: fall back to stateless approval.
        reconcile_label true
        return 0
    fi

    if ! echo "${OWNERS_AREA_APPROVERS}" | awk '{ $1 = ""; print }' | tr ' ' '\n' | grep -qxF "${login}"; then
        echo "[FAIL] You are not an approver of any changed area."
        return 1
    fi

    local old_state=""
    local id
    id="$(find_status_comment)"
    if [[ -n "${id}" ]]; then
        old_state="$(get_status_state "${id}")"
    fi

    local state
    state="$(build_state "${old_state}")"

    local new_state=""
    local all_approved=true
    local pending=""
    local area approved approvers
    while read -r area approved; do
        [[ -z "${area}" ]] && continue
        approvers="$(echo "${OWNERS_AREA_APPROVERS}" | awk -v a="${area}" '$1 == a { $1 = ""; print substr($0, 2) }')"
        if echo "${approvers}" | tr ' ' '\n' | grep -qxF "${login}" &&
            ! echo "${approved}" | tr ' ' '\n' | grep -qxF "${login}"; then
            approved="$(echo "${approved} ${login}" | sed 's/^ *//')"
            echo "Area '${area}' approved by ${login}" >&2
        fi
        if [[ -z "${approved}" ]]; then
            all_approved=false
            pending="${pending} \`${area}\`"
        fi
        new_state="${new_state}${area} ${approved}
"
    done <<<"${state}"
    new_state="$(echo "${new_state}" | sed '/^$/d' | sed 's/ *$//')"

    save_status_comment "${new_state}"
    reconcile_label "${all_approved}"

    if [[ "${all_approved}" == "true" ]]; then
        echo "All areas approved." >&2
        return 0
    fi

    echo "Areas still requiring approval:${pending}." >&2
    return 0
}

function cmd_unapprove() {
    local login="$1"

    if [[ -z "${OWNERS_AREA_APPROVERS}" ]]; then
        reconcile_label false
        return 0
    fi

    local old_state=""
    local id
    id="$(find_status_comment)"
    if [[ -n "${id}" ]]; then
        old_state="$(get_status_state "${id}")"
    fi

    local state
    state="$(build_state "${old_state}")"

    local new_state=""
    local area approved
    while read -r area approved; do
        [[ -z "${area}" ]] && continue
        approved="$(echo "${approved}" | tr ' ' '\n' | grep -vxF "${login}" | tr '\n' ' ' | sed 's/ *$//')"
        new_state="${new_state}${area} ${approved}
"
    done <<<"${state}"
    new_state="$(echo "${new_state}" | sed '/^$/d' | sed 's/ *$//')"

    save_status_comment "${new_state}"
    if state_all_approved "${new_state}"; then
        reconcile_label true
    else
        reconcile_label false
    fi
}

# cmd_sync recomputes the state against the current change set without
# recording any new approval. Used when the PR is opened or synchronized:
# approvals are sticky, but new areas may need approval again.
function cmd_sync() {
    if [[ -z "${OWNERS_AREA_APPROVERS}" ]]; then
        return 0
    fi

    local old_state=""
    local id
    id="$(find_status_comment)"
    if [[ -n "${id}" ]]; then
        old_state="$(get_status_state "${id}")"
    fi

    local state
    state="$(build_state "${old_state}")"

    save_status_comment "${state}"
    if state_all_approved "${state}"; then
        reconcile_label true
    else
        reconcile_label false
    fi
}

# cmd_check succeeds only when every changed area is approved (or no
# OWNERS areas are defined). Used as a gate by check-auto-merge.sh.
function cmd_check() {
    if [[ -z "${OWNERS_AREA_APPROVERS}" ]]; then
        return 0
    fi

    local old_state=""
    local id
    id="$(find_status_comment)"
    if [[ -n "${id}" ]]; then
        old_state="$(get_status_state "${id}")"
    fi

    state_all_approved "$(build_state "${old_state}")"
}

# Incomplete OWNERS data must neither grant, revoke nor reconcile approvals.
if [[ -n "${OWNERS_LOAD_FAILED:-}" ]]; then
    case "$1" in
    approve | unapprove)
        echo "[FAIL] Could not load the OWNERS data of this PR because of an API error. Please try again later."
        exit 1
        ;;
    sync)
        echo "OWNERS data unavailable, skipping the approval sync." >&2
        exit 0
        ;;
    check)
        echo "OWNERS data unavailable, the approvals cannot be verified." >&2
        exit 1
        ;;
    esac
fi

case "$1" in
approve)
    cmd_approve "$2"
    ;;
unapprove)
    cmd_unapprove "$2"
    ;;
sync)
    cmd_sync
    ;;
check)
    cmd_check
    ;;
*)
    echo "Usage: approve-status.sh {approve <login>|unapprove <login>|sync|check}" >&2
    exit 1
    ;;
esac
