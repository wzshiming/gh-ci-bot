#!/usr/bin/env bash

ROOT="$(dirname "${BASH_SOURCE}")"
ROOT="$(realpath -m ${ROOT})"
PLUGINS_DIR="${ROOT}/../plugins"
PLUGINS_DIR="$(realpath -m ${PLUGINS_DIR})"

PLUGINS="${PLUGINS:-}"

# Load OWNERS file reviewers and approvers for PRs
if [[ "${ISSUE_KIND}" == "pr" && "${ISSUE_NUMBER}" != "" && "${GH_REPOSITORY}" != "" ]]; then
    source "${ROOT}/owners.sh"
    load_owners_for_pr
fi

# Added more plugins for members
if [[ "${LOGIN}" != "" ]] && [[ "${AUTHOR_ASSOCIATION}" =~ ^(OWNER|MEMBER|COLLABORATOR|CONTRIBUTOR)$ ]]; then
    PLUGINS="${PLUGINS}
${MEMBERS_PLUGINS:-}"
    echo "${LOGIN} is a member"

    # Added more plugins for reviewers
    if [[ "${REVIEWERS}" != "" && "${REVIEWERS_PLUGINS}" != "" ]] && grep -qixF -e "${LOGIN}" <<<"${REVIEWERS}"; then
        echo "${LOGIN} is a reviewer"
        PLUGINS="${PLUGINS}
${REVIEWERS_PLUGINS:-}"
    fi

    # Added more plugins for approvers
    if [[ "${APPROVERS}" != "" && "${APPROVERS_PLUGINS}" != "" ]] && grep -qixF -e "${LOGIN}" <<<"${APPROVERS}"; then
        echo "${LOGIN} is a approver"
        PLUGINS="${PLUGINS}
${APPROVERS_PLUGINS:-}"
    fi

    # Added more plugins for maintainers
    if [[ "${MAINTAINERS}" != "" && "${MAINTAINERS_PLUGINS}" != "" ]] && grep -qixF -e "${LOGIN}" <<<"${MAINTAINERS}"; then
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
    local cmdpath="$(which "${cmd}.plugin.sh")"
    if [[ -z "${cmdpath}" ]]; then
        local dir
        for dir in "${PLUGINS_DIR}"/*/; do
            if [[ -e "${dir}${cmd}.plugin.sh" ]]; then
                echo "[FAIL] You don't have permission to use the \`/${cmd}\` command. Please contact a maintainer for access."
                return 1
            fi
        done
        echo "[FAIL] Unknown command \`/${cmd}\`. Please check the available commands and try again."
        return 1
    fi

    if ! [[ "${cmdpath}" == "${PLUGINS_DIR}/"* ]]; then
        echo "[FAIL] Unknown command \`/${cmd}\`. Please check the available commands and try again."
        return 1
    fi
    shift
    "${cmdpath}" "$@"
}

# Drop HTML comments (unterminated ones hide everything to EOF, like GitHub
# rendering) and fenced code blocks; awk keeps it portable across GNU/BSD.
function clearComment() {
    awk '
    function stripComments(line,    s, e, out) {
        out = ""
        while ((s = index(line, "<!--")) > 0) {
            e = index(substr(line, s + 4), "-->")
            if (e == 0) {
                inComment = 1
                return out substr(line, 1, s - 1)
            }
            out = out substr(line, 1, s - 1) "COMMENT"
            line = substr(line, s + e + 6)
        }
        return out line
    }
    # fenceTicks: number of leading fence chars; sets fenceChar and fenceRest.
    function fenceTicks(line,    i, n, ch) {
        i = 1
        while (i <= 3 && substr(line, i, 1) == " ") i++
        ch = substr(line, i, 1)
        fenceChar = ""
        fenceRest = ""
        if (ch != "`" && ch != "~") return 0
        n = 0
        while (substr(line, i + n, 1) == ch) n++
        fenceChar = ch
        fenceRest = substr(line, i + n)
        return n
    }
    {
        line = $0
        if (inComment) {
            e = index(line, "-->")
            if (e == 0) next
            inComment = 0
            line = "COMMENT" substr(line, e + 3)
        }
        n = fenceTicks(line)
        if (inFence) {
            # Closer: same char, at least as many, nothing else on the line.
            if (n >= fenceOpen && fenceChar == openChar && fenceRest ~ /^[ \t\r]*$/) inFence = 0
            next
        }
        # A backtick opener with a backtick in its info string is plain text.
        if (n >= 3 && !(fenceChar == "`" && index(fenceRest, "`") > 0)) {
            inFence = 1
            fenceOpen = n
            openChar = fenceChar
            next
        }
        print stripComments(line)
    }
    '
}

function extractCommand() {
    grep -e '^/[a-z]\+'
}

function main() {
    if [[ "${MESSAGE}" == "" ]]; then
        return 0
    fi
    printf '%s\n' "${MESSAGE}" |
        clearComment |
        extractCommand | while IFS= read -r line; do
        line="${line//$'\r'/}"
        read -r -a cmd <<<"${line#/}"
        echo "Exec command: ${cmd[@]}"
        exec_cmd "${cmd[@]}" || true
    done
}

main
