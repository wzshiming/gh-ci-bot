#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m ${ROOT})"

PATH="${ROOT}/bin:${PATH}"

function check_args() {
    if [[ "${LOGIN}" == "" ]]; then
        echo "No login specified"
        exit 1
    fi

    if [[ "${ISSUE_KIND}" == "" ]]; then
        echo "No issue kind specified"
        exit 1
    fi

    if [[ "${ISSUE_NUMBER}" == "" ]]; then
        echo "No issue number specified"
        exit 1
    fi

    if [[ "${GH_REPOSITORY}" == "" ]]; then
        echo "No repository specified"
        exit 1
    fi

    if [[ "${TYPE}" == "" ]]; then
        echo "No type"
        exit 1
    fi
}

function main() {
    if [[ "${TYPE}" == "created" ]]; then
        echo "Greetings to ${LOGIN}!"
        greeting.sh
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "comment" ]]; then
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "synchronize" ]]; then
        echo "PR synchronized, removing lgtm and approved labels"
        remove-labels.sh lgtm
        remove-labels.sh approved
    fi
}

check_args

main
