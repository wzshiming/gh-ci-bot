#!/usr/bin/env bash

# Classify the ```release-note block in the PR body read on stdin and print the release-note label to apply.

content="$(tr -d '\r' | awk '
    /^```/ {
        if (in_block) {
            closed = 1
            exit
        }
        if (tolower($0) ~ /^```[ \t]*release-note[ \t]*$/) {
            in_block = 1
        }
        next
    }
    in_block {
        lines[++n] = $0
    }
    END {
        if (!closed) {
            exit
        }
        start = 1
        end = n
        while (start <= end && lines[start] ~ /^[ \t]*$/) start++
        while (end >= start && lines[end] ~ /^[ \t]*$/) end--
        for (i = start; i <= end; i++) print lines[i]
    }
')"

if [[ -z "${content}" ]]; then
    echo "do-not-merge/release-note-label-needed"
elif [[ "$(tr '[:upper:]' '[:lower:]' <<<"${content}")" =~ ^[^[:alnum:]_]*none[^[:alnum:]_]*$ ]]; then
    echo "release-note-none"
else
    echo "release-note"
fi
