package bot

import (
	"fmt"
	"os"
	"strings"

	"github.com/wzshiming/gh-ci-bot/internal/command"
	"github.com/wzshiming/gh-ci-bot/internal/ghcli"
	"github.com/wzshiming/gh-ci-bot/internal/owners"
	"github.com/wzshiming/gh-ci-bot/internal/plugin"
)

// Run is the main entry point for the bot.
func Run() error {
	login := os.Getenv("LOGIN")
	issueKind := os.Getenv("ISSUE_KIND")
	issueNumber := os.Getenv("ISSUE_NUMBER")
	ghRepository := os.Getenv("GH_REPOSITORY")
	eventType := os.Getenv("TYPE")

	if login == "" {
		return fmt.Errorf("No login specified")
	}
	if issueKind == "" {
		return fmt.Errorf("No issue kind specified")
	}
	if issueNumber == "" {
		return fmt.Errorf("No issue number specified")
	}
	if ghRepository == "" {
		return fmt.Errorf("No repository specified")
	}
	if eventType == "" {
		return fmt.Errorf("No type")
	}

	switch eventType {
	case "created":
		fmt.Printf("Greetings to %s!\n", login)
		greeting(issueKind, ghRepository, issueNumber)
		fmt.Println("Response to action")
		return response(login, issueKind, issueNumber, ghRepository)
	case "comment":
		fmt.Println("Response to action")
		return response(login, issueKind, issueNumber, ghRepository)
	case "synchronize":
		fmt.Println("PR synchronized, removing lgtm and approved labels")
		ghcli.RemoveLabels(issueKind, ghRepository, issueNumber, "lgtm")
		ghcli.RemoveLabels(issueKind, ghRepository, issueNumber, "approved")
		return nil
	}
	return nil
}

func greeting(issueKind, ghRepository, issueNumber string) {
	greetingMsg := os.Getenv("GREETING")
	details := os.Getenv("DETAILS")
	if greetingMsg != "" {
		body := greetingMsg
		if details != "" {
			body += "\n" + details
		}
		ghcli.Comment(issueKind, ghRepository, issueNumber, body)
	}
}

func response(login, issueKind, issueNumber, ghRepository string) error {
	failures := executeCommands(login, issueKind, issueNumber, ghRepository)

	if len(failures) > 0 {
		details := os.Getenv("DETAILS")
		ghToken := os.Getenv("GH_TOKEN")

		var reply strings.Builder
		reply.WriteString(fmt.Sprintf("@%s\n\n", login))
		reply.WriteString("**I encountered an error while processing your command:**\n\n")
		for _, f := range failures {
			// Mask GH_TOKEN in output
			if ghToken != "" {
				f = strings.ReplaceAll(f, ghToken, "***")
			}
			reply.WriteString(fmt.Sprintf("> :x: %s\n", f))
		}
		reply.WriteString("\n")
		if details != "" {
			reply.WriteString(details)
		}
		ghcli.Comment(issueKind, ghRepository, issueNumber, reply.String())
	}

	return nil
}

func parseMultilineEnv(name string) []string {
	val := os.Getenv(name)
	if val == "" {
		return nil
	}
	var result []string
	for _, line := range strings.Split(val, "\n") {
		s := strings.TrimSpace(line)
		if s != "" {
			result = append(result, s)
		}
	}
	return result
}

func executeCommands(login, issueKind, issueNumber, ghRepository string) []string {
	message := os.Getenv("MESSAGE")
	if message == "" {
		return nil
	}

	author := os.Getenv("AUTHOR")
	authorAssociation := os.Getenv("AUTHOR_ASSOCIATION")
	ghToken := os.Getenv("GH_TOKEN")

	reviewers := parseMultilineEnv("REVIEWERS")
	approversList := parseMultilineEnv("APPROVERS")
	maintainers := parseMultilineEnv("MAINTAINERS")

	// Load OWNERS file reviewers and approvers for PRs
	if issueKind == "pr" && issueNumber != "" && ghRepository != "" {
		branch := ghcli.GetDefaultBranch(ghRepository)
		reviewers, approversList = owners.LoadOwnersForPR(ghRepository, issueNumber, branch, reviewers, approversList)
	}

	// Resolve enabled plugins based on user permissions
	envPlugins := map[string]string{
		"PLUGINS":            os.Getenv("PLUGINS"),
		"AUTHOR_PLUGINS":     os.Getenv("AUTHOR_PLUGINS"),
		"MEMBERS_PLUGINS":    os.Getenv("MEMBERS_PLUGINS"),
		"REVIEWERS_PLUGINS":  os.Getenv("REVIEWERS_PLUGINS"),
		"APPROVERS_PLUGINS":  os.Getenv("APPROVERS_PLUGINS"),
		"MAINTAINERS_PLUGINS": os.Getenv("MAINTAINERS_PLUGINS"),
		"OWNERS_PLUGINS":     os.Getenv("OWNERS_PLUGINS"),
	}

	enabledPlugins := plugin.ResolveEnabledPlugins(login, author, authorAssociation, reviewers, approversList, maintainers, envPlugins)

	// Print enabled plugins
	fmt.Println("PLUGINS:")
	for _, p := range plugin.SortedPluginList(enabledPlugins) {
		fmt.Printf("- %s\n", p)
	}

	enabledCmds := plugin.EnabledCommands(enabledPlugins)
	allKnown := plugin.AllKnownCommands()

	// Create plugin context
	ctx := &plugin.Context{
		Login:        login,
		Author:       author,
		IssueKind:    issueKind,
		IssueNumber:  issueNumber,
		GHRepository: ghRepository,
		GHToken:      ghToken,
		Reviewers:    reviewers,
		Approvers:    approversList,
		Maintainers:  maintainers,
	}

	// Parse and execute commands
	cleared := command.ClearComment(message)
	commands := command.ExtractCommands(cleared)

	var failures []string
	for _, line := range commands {
		cmdName, args := command.ParseCommandLine(line)
		if cmdName == "" {
			continue
		}

		fmt.Printf("Exec command: %s %s\n", cmdName, strings.Join(args, " "))

		if !enabledCmds[cmdName] {
			if allKnown[cmdName] {
				failures = append(failures, fmt.Sprintf("You don't have permission to use the `/%s` command. Please contact a maintainer for access.", cmdName))
			} else {
				failures = append(failures, fmt.Sprintf("Unknown command `/%s`. Please check the available commands and try again.", cmdName))
			}
			continue
		}

		handler := plugin.GetHandler(cmdName)
		if handler == nil {
			failures = append(failures, fmt.Sprintf("Unknown command `/%s`. Please check the available commands and try again.", cmdName))
			continue
		}

		if err := handler(ctx, args); err != nil {
			failures = append(failures, err.Error())
		}
	}

	return failures
}
