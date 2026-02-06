#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m ${ROOT})"
PLUGINS_DIR="${ROOT}/../plugins"
PLUGINS_DIR="$(realpath -m ${PLUGINS_DIR})"
ALL_PLUGINS="$(ls ${PLUGINS_DIR})"

# Source the owners utility for merging OWNERS file data
source "${ROOT}/owners.sh"

# Merge OWNERS file reviewers/approvers with environment variables for PRs
if [[ "${ISSUE_KIND}" == "pr" && -n "${ISSUE_NUMBER}" ]]; then
    echo "Loading OWNERS files for PR #${ISSUE_NUMBER}..."
    
    # Get changed files in the PR
    _changed_files="$(get_pr_changed_files 2>/dev/null)"
    
    if [[ -n "${_changed_files}" ]]; then
        # Get reviewers from OWNERS files and merge with REVIEWERS env var
        _owners_reviewers="$(get_reviewers_for_files ${_changed_files} 2>/dev/null)"
        if [[ -n "${_owners_reviewers}" ]]; then
            if [[ -n "${REVIEWERS}" ]]; then
                # Merge, avoiding duplicates
                REVIEWERS="$(echo -e "${REVIEWERS}\n${_owners_reviewers}" | sort -u)"
            else
                REVIEWERS="${_owners_reviewers}"
            fi
            echo "Merged reviewers from OWNERS files"
        fi
        
        # Get approvers from OWNERS files and merge with APPROVERS env var
        _owners_approvers="$(get_approvers_for_files ${_changed_files} 2>/dev/null)"
        if [[ -n "${_owners_approvers}" ]]; then
            if [[ -n "${APPROVERS}" ]]; then
                # Merge, avoiding duplicates
                APPROVERS="$(echo -e "${APPROVERS}\n${_owners_approvers}" | sort -u)"
            else
                APPROVERS="${_owners_approvers}"
            fi
            echo "Merged approvers from OWNERS files"
        fi
    fi
fi

PLUGINS="${PLUGINS:-}"

# Added more plugins for members
if [[ "${LOGIN}" != "" && "${AUTHOR_ASSOCIATION}" != "NONE" && "${AUTHOR_ASSOCIATION}" != "" ]]; then
    PLUGINS="${PLUGINS}
${MEMBERS_PLUGINS:-}"
    echo "${LOGIN} is a member"

    # Added more plugins for reviewers
    if [[ "${REVIEWERS}" != "" && "${REVIEWERS_PLUGINS}" != "" && $(echo "${REVIEWERS}" | grep -e "^${LOGIN}$") == "${LOGIN}" ]]; then
        echo "${LOGIN} is a reviewer"
        PLUGINS="${PLUGINS}
${REVIEWERS_PLUGINS:-}"
    fi

    # Added more plugins for approvers
    if [[ "${APPROVERS}" != "" && "${APPROVERS_PLUGINS}" != "" && $(echo "${APPROVERS}" | grep -e "^${LOGIN}$") == "${LOGIN}" ]]; then
        echo "${LOGIN} is a approver"
        PLUGINS="${PLUGINS}
${APPROVERS_PLUGINS:-}"
    fi

    # Added more plugins for maintainers
    if [[ "${MAINTAINERS}" != "" && "${MAINTAINERS_PLUGINS}" != "" && $(echo "${MAINTAINERS}" | grep -e "^${LOGIN}$") == "${LOGIN}" ]]; then
        echo "${LOGIN} is a maintainer"
        PLUGINS="${PLUGINS}
${MAINTAINERS_PLUGINS:-}"
    fi

    # Added more plugins for owners
    if [[ "${AUTHOR_ASSOCIATION}" == "OWNER" ]]; then
        echo "${LOGIN} is a owner"
        PLUGINS="${PLUGINS}
${OWNERS_PLUGINS:-}"
    fi
fi

if [[ "${LOGIN}" == "${AUTHOR}" && "${AUTHOR_PLUGINS}" != "" ]]; then
    echo "${LOGIN} is author"
    PLUGINS="${PLUGINS}
${AUTHOR_PLUGINS:-}"
fi

PLUGINS="$(echo "${PLUGINS}" | sort -u)"

echo "PLUGINS:"
for plugin in ${PLUGINS}; do
    echo "- ${plugin}"
done

function load_plugins() {
    for plugin in ${PLUGINS}; do
        echo "${PLUGINS_DIR}/${plugin}"
    done | tr '\n' ':'
}

PATH="$(load_plugins):${PATH}"

function exec_cmd() {
    local cmd="$1"
    local cmdpath="$(which ${cmd}.plugin.sh)"
    if [[ -z "${cmdpath}" ]]; then
        if [[ "${ALL_PLUGINS}" =~ "${cmd}" ]]; then
            echo "[FAIL] You don't have permission to use the \`/${cmd}\` command. Please contact a maintainer for access."
        else
            echo "[FAIL] Unknown command \`/${cmd}\`. Please check the available commands and try again."
        fi
        return 1
    fi

    if ! [[ "${cmdpath}" =~ ^${PLUGINS_DIR} ]]; then
        echo "[FAIL] Unknown command \`/${cmd}\`. Please check the available commands and try again."
        return 1
    fi
    shift
    "${cmdpath}" $@
}

function clearComment() {
    sed -e ':begin; /<!--/,/-->/ { /-->/! { $! { N; b begin }; }; s/<!--.*-->/COMMENT/; };'
}

function extractCommand() {
    grep -e '^/[a-z]\+'
}

function main() {
    if [[ "${MESSAGE}" == "" ]]; then
        return 0
    fi
    echo "${MESSAGE}" |
        clearComment |
        extractCommand | while read line; do
        line=$(echo ${line} | sed 's/\t/ /g' | sed 's/  */ /g' | tr -d '\r')
        cmd=("${line#/}")
        echo "Exec command: ${cmd[@]}"
        exec_cmd ${cmd[@]} || true
    done
}

main
