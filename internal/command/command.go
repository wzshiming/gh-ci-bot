package command

import (
	"regexp"
	"strings"
)

var htmlCommentRe = regexp.MustCompile(`(?s)<!--.*?-->`)

// ClearComment removes HTML comments from the input string.
func ClearComment(s string) string {
	return htmlCommentRe.ReplaceAllString(s, "COMMENT")
}

// ExtractCommands extracts lines that start with a slash command (e.g., /assign).
func ExtractCommands(s string) []string {
	var commands []string
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		if matched, _ := regexp.MatchString(`^/[a-z]`, line); matched {
			commands = append(commands, line)
		}
	}
	return commands
}

// ParseCommandLine normalizes a command line by replacing tabs with spaces,
// collapsing multiple spaces, removing carriage returns, and stripping the leading slash.
// Returns the command name and arguments.
func ParseCommandLine(line string) (string, []string) {
	line = strings.ReplaceAll(line, "\t", " ")
	line = strings.TrimSpace(line)
	line = strings.Replace(line, "\r", "", -1)

	// Collapse multiple spaces
	spaceRe := regexp.MustCompile(`\s+`)
	line = spaceRe.ReplaceAllString(line, " ")

	// Strip leading /
	line = strings.TrimPrefix(line, "/")

	parts := strings.Fields(line)
	if len(parts) == 0 {
		return "", nil
	}
	var args []string
	if len(parts) > 1 {
		args = parts[1:]
	}
	return parts[0], args
}
