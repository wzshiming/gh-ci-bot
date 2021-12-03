#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m ${ROOT})"
PLUGINS_DIR="${ROOT}/../plugins"
PLUGINS_DIR="$(realpath -m ${PLUGINS_DIR})"
ALL_PLUGINS="$(ls ${PLUGINS_DIR})"

PLUGINS="${PLUGINS:-}"

# Added more plugins for members
if [[ "${LOGIN}" != "" && "${AUTHOR_ASSOCIATION}" != "NONE" && "${AUTHOR_ASSOCIATION}" != "" ]]; then
    PLUGINS="${PLUGINS}
${MEMBERS_PLUGINS:-}"
    echo "${LOGIN} is a member"

    # Added more plugins for reviewers
    if [[ "${REVIEWERS}" != "" && "${REVIEWERS_PLUGINS}" != "" && "${REVIEWERS}" =~ ^${LOGIN}$ ]]; then
        echo "${LOGIN} is a reviewer"
        PLUGINS="${PLUGINS}
${REVIEWERS_PLUGINS:-}"
    fi

    # Added more plugins for approvers
    if [[ "${APPROVERS}" != "" && "${APPROVERS_PLUGINS}" != "" && "${APPROVERS}" =~ ^${LOGIN}$ ]]; then
        echo "${LOGIN} is a approver"
        PLUGINS="${PLUGINS}
${APPROVERS_PLUGINS:-}"
    fi

    # Added more plugins for maintainers
    if [[ "${MAINTAINERS}" != "" && "${MAINTAINERS_PLUGINS}" != "" && "${MAINTAINERS}" =~ ^${LOGIN}$ ]]; then
        echo "${LOGIN} is a maintainer"
        PLUGINS="${PLUGINS}
${MAINTAINERS_PLUGINS:-}"
    fi

    # Added more plugins for owners
    if [[ "${AUTHOR_ASSOCIATION}" != "OWNER" ]]; then
        echo "${LOGIN} is a owner"
        PLUGINS="${PLUGINS}
${OWNERS_PLUGINS:-}"
    fi
fi

echo "PLUGINS: ${PLUGINS}"

function load_plugins() {
    for plugin in ${PLUGINS}; do
        echo "${PLUGINS_DIR}/${plugin}"
    done | tr '\n' ':'
}

PATH="$(load_plugins):${PATH}"

function exec_cmd() {
    local cmd="$1"
    local cmdpath="$(which ${cmd}.sh)"
    if [[ -z "${cmdpath}" ]]; then
        if [[ "${ALL_PLUGINS}" =~ "${cmd}" ]]; then
            echo "[FAIL] You do not support using command ${cmd}"
        else
            echo "[FAIL] Command ${cmd} is not found"
        fi
        return 1
    fi

    if ! [[ "${cmdpath}" =~ ^${PLUGINS_DIR} ]]; then
        echo "[FAIL] Command ${cmd} is not found"
        return 1
    fi
    shift
    "${cmdpath}" $@
}

function main() {
    if [[ "${MESSAGE}" == "" ]]; then
        return 0
    fi
    echo "${MESSAGE}" | grep -e '^/[a-z]\+' | while read line; do
        line=$(echo ${line} | sed 's/\t/ /g' | sed 's/  */ /g' | tr -d '\r')
        cmd=("${line#/}")
        echo "Exec command: ${cmd[@]}"
        exec_cmd ${cmd[@]} || true
    done
}

main
