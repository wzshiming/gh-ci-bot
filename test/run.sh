#!/usr/bin/env bash

# run.sh - Run the bot's test suite: every spec in test/specs, or only the
# specs given as arguments (by path or by name, e.g. release-note).
#
#   ./test/run.sh
#   ./test/run.sh release-note check-wip
#
# The specs run the real scripts (bin/*.sh, plugins/**/*.plugin.sh,
# entrypoint.sh) against the mocked gh/curl in test/mock; no network, no
# GitHub, no dependencies beyond bash and jq.
#
# Note for macOS: the scripts use `realpath -m`, which needs GNU coreutils
# (brew install coreutils). CI's ubuntu runners have everything built in.

set -eu

TEST_DIR="$(dirname "${BASH_SOURCE[0]}")"

if ! realpath -m "${TEST_DIR}" >/dev/null 2>&1; then
    echo "error: 'realpath -m' is not supported; on macOS install GNU coreutils (brew install coreutils)" >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to run the tests" >&2
    exit 1
fi

TEST_DIR="$(realpath -m "${TEST_DIR}")"

specs=()
if [[ "${#}" -eq 0 ]]; then
    specs=("${TEST_DIR}/specs/"*.sh)
else
    for arg in "${@}"; do
        if [[ -f "${arg}" ]]; then
            specs+=("${arg}")
        elif [[ -f "${TEST_DIR}/specs/${arg%.sh}.sh" ]]; then
            specs+=("${TEST_DIR}/specs/${arg%.sh}.sh")
        else
            echo "error: no such spec: ${arg}" >&2
            exit 1
        fi
    done
fi

failed=0
for spec in "${specs[@]}"; do
    echo "=== $(basename "${spec}" .sh)"
    if ! bash "${spec}"; then
        failed=$((failed + 1))
    fi
done

echo "==="
if [[ "${failed}" -ne 0 ]]; then
    echo "FAIL: ${failed} of ${#specs[@]} specs failed"
    exit 1
fi
echo "PASS: all ${#specs[@]} specs passed"
