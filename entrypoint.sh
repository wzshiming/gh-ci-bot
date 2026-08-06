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

# auto_cc proactively triggers the auto-cc plugin on pull requests when
# it is enabled and no reviewer has been requested or reviewed yet.
function auto_cc() {
    if [[ "${ISSUE_KIND}" != "pr" ]]; then
        return 0
    fi

    if [[ "${AUTO_CC:-true}" != "true" ]]; then
        return 0
    fi

    if ! echo "${PLUGINS:-}" | grep -q -e '^auto-cc$'; then
        return 0
    fi

    local requested_reviewers
    requested_reviewers="$(gh api "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}" --jq '(.requested_reviewers | length) + (.requested_teams | length)')"
    if [[ "${requested_reviewers}" != "0" ]]; then
        echo "Reviewers already requested, skipping proactive auto-cc"
        return 0
    fi

    local reviews
    reviews="$(gh api "/repos/${GH_REPOSITORY}/pulls/${ISSUE_NUMBER}/reviews" --jq 'length')"
    if [[ "${reviews}" != "0" ]]; then
        echo "Reviews already exist, skipping proactive auto-cc"
        return 0
    fi

    echo "Proactively triggering auto-cc"
    MESSAGE="/auto-cc" response.sh
}

function main() {
    if [[ "${TYPE}" == "created" ]]; then
        echo "Greetings to ${LOGIN}!"
        greeting.sh
        echo "Response to action"
        response.sh
        auto_cc
    elif [[ "${TYPE}" == "comment" ]]; then
        echo "Response to action"
        response.sh
    elif [[ "${TYPE}" == "synchronize" ]]; then
        echo "PR synchronized, removing lgtm and approved labels"
        remove-labels.sh lgtm
        remove-labels.sh approved
        auto_cc
    fi
}

check_args

main
