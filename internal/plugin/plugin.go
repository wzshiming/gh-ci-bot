package plugin

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"sort"
	"strings"

	"github.com/wzshiming/gh-ci-bot/internal/ghcli"
	"github.com/wzshiming/gh-ci-bot/internal/owners"
	"gopkg.in/yaml.v3"
)

// Context holds all the information needed to execute plugin commands.
type Context struct {
	Login        string
	Author       string
	IssueKind    string
	IssueNumber  string
	GHRepository string
	GHToken      string
	Reviewers    []string
	Approvers    []string
	Maintainers  []string
}

// CommandHandler is a function that handles a command.
type CommandHandler func(ctx *Context, args []string) error

// PluginCommands maps plugin group names to the command names they provide.
var PluginCommands = map[string][]string{
	"assign":              {"assign", "unassign"},
	"auto-cc":             {"auto-cc"},
	"base":                {"base"},
	"cc":                  {"cc", "uncc"},
	"cherry-pick":         {"cherry-pick"},
	"label":               {"label", "remove-label"},
	"label-approve":       {"approve", "remove-approve"},
	"label-bug":           {"bug", "remove-bug"},
	"label-documentation": {"documentation", "remove-documentation"},
	"label-duplicate":     {"duplicate", "remove-duplicate"},
	"label-enhancement":   {"enhancement", "remove-enhancement"},
	"label-good-first-issue": {"good-first-issue", "remove-good-first-issue"},
	"label-help-wanted":   {"help-wanted", "remove-help-wanted"},
	"label-invalid":       {"invalid", "remove-invalid"},
	"label-kind":          {"kind", "remove-kind"},
	"label-lgtm":          {"lgtm", "remove-lgtm"},
	"label-question":      {"question", "remove-question"},
	"label-wontfix":       {"wontfix", "remove-wontfix"},
	"lifecycle":           {"close", "reopen"},
	"merge":               {"merge"},
	"milestone":           {"milestone", "remove-milestone"},
	"rebase":              {"rebase"},
	"retest":              {"retest"},
	"retitle":             {"retitle"},
}

// commandHandlers maps command names to their handler functions.
var commandHandlers = map[string]CommandHandler{
	"assign":                assignCmd,
	"unassign":              unassignCmd,
	"auto-cc":               autoCCCmd,
	"base":                  baseCmd,
	"cc":                    ccCmd,
	"uncc":                  unccCmd,
	"cherry-pick":           cherryPickCmd,
	"label":                 labelCmd,
	"remove-label":          removeLabelCmd,
	"approve":               approveCmd,
	"remove-approve":        removeApproveCmd,
	"bug":                   bugCmd,
	"remove-bug":            removeBugCmd,
	"documentation":         documentationCmd,
	"remove-documentation":  removeDocumentationCmd,
	"duplicate":             duplicateCmd,
	"remove-duplicate":      removeDuplicateCmd,
	"enhancement":           enhancementCmd,
	"remove-enhancement":    removeEnhancementCmd,
	"good-first-issue":      goodFirstIssueCmd,
	"remove-good-first-issue": removeGoodFirstIssueCmd,
	"help-wanted":           helpWantedCmd,
	"remove-help-wanted":    removeHelpWantedCmd,
	"invalid":               invalidCmd,
	"remove-invalid":        removeInvalidCmd,
	"kind":                  kindCmd,
	"remove-kind":           removeKindCmd,
	"lgtm":                  lgtmCmd,
	"remove-lgtm":           removeLgtmCmd,
	"question":              questionCmd,
	"remove-question":       removeQuestionCmd,
	"wontfix":               wontfixCmd,
	"remove-wontfix":        removeWontfixCmd,
	"close":                 closeCmd,
	"reopen":                reopenCmd,
	"merge":                 mergeCmd,
	"milestone":             milestoneCmd,
	"remove-milestone":      removeMilestoneCmd,
	"rebase":                rebaseCmd,
	"retest":                retestCmd,
	"retitle":               retitleCmd,
}

// AllKnownCommands returns a set of all known command names.
func AllKnownCommands() map[string]bool {
	known := make(map[string]bool)
	for _, cmds := range PluginCommands {
		for _, cmd := range cmds {
			known[cmd] = true
		}
	}
	return known
}

// GetHandler returns the handler for a command, or nil if not found.
func GetHandler(cmd string) CommandHandler {
	return commandHandlers[cmd]
}

// --- Helper functions ---

func stripAt(s string) string {
	return strings.ReplaceAll(s, "@", "")
}

func parseLogins(args []string, defaultLogin string) []string {
	if len(args) == 0 {
		return []string{defaultLogin}
	}
	var logins []string
	for _, a := range args {
		a = stripAt(a)
		if a != "" {
			logins = append(logins, a)
		}
	}
	return logins
}

func requirePR(ctx *Context) error {
	if ctx.IssueKind != "pr" {
		return fmt.Errorf("This command is only available on pull requests, not on issues.")
	}
	return nil
}

// --- Assign commands ---

func assignCmd(ctx *Context, args []string) error {
	logins := parseLogins(args, ctx.Login)
	fmt.Printf("Add assignee %s to %s#%s\n", strings.Join(logins, ","), ctx.GHRepository, ctx.IssueNumber)
	return ghcli.AddAssignees(ctx.GHRepository, ctx.IssueNumber, ctx.GHToken, logins)
}

func unassignCmd(ctx *Context, args []string) error {
	logins := parseLogins(args, ctx.Login)
	fmt.Printf("Remove assignee %s to %s#%s\n", strings.Join(logins, ","), ctx.GHRepository, ctx.IssueNumber)
	return ghcli.RemoveAssignees(ctx.GHRepository, ctx.IssueNumber, ctx.GHToken, logins)
}

// --- Auto-CC command ---

func autoCCCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}

	branch := ghcli.GetDefaultBranch(ctx.GHRepository)

	files, err := owners.GetPRChangedFiles(ctx.GHRepository, ctx.IssueNumber)
	if err != nil {
		return fmt.Errorf("Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured.")
	}

	fmt.Println("Modify files:")
	for _, f := range files {
		fmt.Printf("- %s\n", f)
	}

	// Get reviewer from OWNERS files for each changed file
	type reviewerFromDir struct {
		user string
		dir  string
	}

	userPool := make(map[string]bool)
	// Author is excluded from reviewer pool
	userPool[ctx.Author] = true

	usedDirs := make(map[string]bool)

	var selectedReviewers []string

	// getParent returns the parent directory of a path
	getParent := func(dir string) string {
		if idx := strings.LastIndex(dir, "/"); idx >= 0 {
			return dir[:idx]
		}
		return ""
	}

	// getReviewerFromFile fetches reviewers from OWNERS file in the given directory
	getReviewerFromFile := func(dir string) []string {
		url := fmt.Sprintf("https://github.com/%s/raw/%s/%s/OWNERS", ctx.GHRepository, branch, dir)
		if dir == "" {
			url = fmt.Sprintf("https://github.com/%s/raw/%s/OWNERS", ctx.GHRepository, branch)
		}
		content, err := ghcli.FetchURL(url)
		if err != nil {
			return nil
		}
		var ownersFile owners.OwnersFile
		if err := parseYAML(content, &ownersFile); err != nil {
			return nil
		}
		return ownersFile.Reviewers
	}

	// getReviewerWithRecursively walks up the directory tree to find a reviewer
	var getReviewerWithRecursively func(dir, origDir string)
	getReviewerWithRecursively = func(dir, origDir string) {
		if usedDirs[dir] {
			return
		}
		usedDirs[dir] = true

		reviewers := getReviewerFromFile(dir)
		if len(reviewers) > 0 {
			// Shuffle reviewers
			shuffled := make([]string, len(reviewers))
			copy(shuffled, reviewers)
			rand.Shuffle(len(shuffled), func(i, j int) {
				shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
			})
			for _, user := range shuffled {
				if !userPool[user] {
					userPool[user] = true
					selectedReviewers = append(selectedReviewers, user)
					if origDir == dir {
						fmt.Printf("Add %s for %s\n", user, origDir)
					} else {
						fmt.Printf("Add %s for %s take on %s\n", user, origDir, dir)
					}
					return
				}
			}
			return
		}

		parent := getParent(dir)
		if parent == dir {
			return
		}
		getReviewerWithRecursively(parent, dir)
	}

	for _, file := range files {
		fileDir := getParent(file)
		getReviewerWithRecursively(fileDir, file)
	}

	login := strings.Join(selectedReviewers, ",")
	if login == "" {
		// Fallback: use REVIEWERS environment variable
		fmt.Println("Fallback use REVIEWERS environment variable")
		if len(ctx.Reviewers) == 0 {
			return fmt.Errorf("Could not find any reviewers to assign. Please make sure the OWNERS file or REVIEWERS are configured.")
		}
		// Shuffle and pick up to 2
		shuffled := make([]string, len(ctx.Reviewers))
		copy(shuffled, ctx.Reviewers)
		rand.Shuffle(len(shuffled), func(i, j int) {
			shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
		})
		count := 2
		if len(shuffled) < count {
			count = len(shuffled)
		}
		login = strings.Join(shuffled[:count], ",")
	}

	fmt.Printf("Auto-ccing %s.\n", login)
	logins := strings.Split(login, ",")
	for i, l := range logins {
		logins[i] = stripAt(l)
	}
	return ghcli.AddReviewers(ctx.GHRepository, ctx.IssueNumber, ctx.GHToken, logins)
}

func parseYAML(content string, v interface{}) error {
	return yaml.Unmarshal([]byte(content), v)
}

// --- Base command ---

func baseCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	if len(args) == 0 || args[0] == "" {
		return fmt.Errorf("Missing required argument: branch name. Usage: `/base <branch>`")
	}
	return ghcli.EditBase(ctx.GHRepository, ctx.IssueNumber, args[0])
}

// --- CC commands ---

func ccCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	logins := parseLogins(args, ctx.Login)
	fmt.Printf("Add reviewer %s to %s#%s\n", strings.Join(logins, ","), ctx.GHRepository, ctx.IssueNumber)
	return ghcli.AddReviewers(ctx.GHRepository, ctx.IssueNumber, ctx.GHToken, logins)
}

func unccCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	logins := parseLogins(args, ctx.Login)
	fmt.Printf("Remove reviewer %s to %s#%s\n", strings.Join(logins, ","), ctx.GHRepository, ctx.IssueNumber)
	return ghcli.RemoveReviewers(ctx.GHRepository, ctx.IssueNumber, ctx.GHToken, logins)
}

// --- Cherry-pick command ---

func cherryPickCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	if len(args) == 0 || args[0] == "" {
		return fmt.Errorf("Missing required argument: branch name. Usage: `/cherry-pick <branch>`")
	}
	branch := args[0]

	// Check if the PR is merged
	state, err := ghcli.RunGH("pr", "-R", ctx.GHRepository, "view", ctx.IssueNumber, "--json", "state", "--jq", ".state")
	if err != nil {
		return fmt.Errorf("Could not check PR state.")
	}
	if state != "MERGED" {
		return fmt.Errorf("The PR must be merged before cherry-picking. Please merge the PR first.")
	}

	// Get the merge commit SHA
	mergeCommit, err := ghcli.RunGH("pr", "-R", ctx.GHRepository, "view", ctx.IssueNumber, "--json", "mergeCommit", "--jq", ".mergeCommit.oid")
	if err != nil || mergeCommit == "" || mergeCommit == "null" {
		return fmt.Errorf("Could not find the merge commit for this PR.")
	}

	// Get the PR title
	prTitle, err := ghcli.RunGH("pr", "-R", ctx.GHRepository, "view", ctx.IssueNumber, "--json", "title", "--jq", ".title")
	if err != nil {
		return fmt.Errorf("Could not get PR title.")
	}

	cherryPickBranch := fmt.Sprintf("cherry-pick-%s-to-%s", ctx.IssueNumber, branch)

	// Create temp directory
	tmpdir, err := os.MkdirTemp("", "cherry-pick-*")
	if err != nil {
		return fmt.Errorf("Failed to create temp directory.")
	}
	defer os.RemoveAll(tmpdir)

	// Clone the repository
	cloneURL := fmt.Sprintf("https://x-access-token:%s@github.com/%s.git", ctx.GHToken, ctx.GHRepository)
	output, err := ghcli.RunGit("", "clone", cloneURL, tmpdir, "--branch", branch)
	if err != nil {
		fmt.Print(output)
		return fmt.Errorf("Failed to clone the repository or branch `%s` does not exist.", branch)
	}

	// Configure git user
	ghcli.RunGit("", "config", "--global", "user.email", "github-actions[bot]@users.noreply.github.com")
	ghcli.RunGit("", "config", "--global", "user.name", "github-actions[bot]")

	// Configure the remote to use the authenticated URL
	ghcli.RunGit(tmpdir, "remote", "set-url", "origin", cloneURL)

	// Create branch and cherry-pick
	if _, err := ghcli.RunGit(tmpdir, "checkout", "-b", cherryPickBranch); err != nil {
		return fmt.Errorf("Failed to create cherry-pick branch.")
	}

	if _, err := ghcli.RunGit(tmpdir, "cherry-pick", mergeCommit, "-m", "1"); err != nil {
		return fmt.Errorf("Cherry-pick failed due to conflicts. Please cherry-pick manually.")
	}

	output, err = ghcli.RunGit(tmpdir, "push", "origin", cherryPickBranch)
	if err != nil {
		fmt.Print(output)
		return fmt.Errorf("Failed to push the cherry-pick branch.")
	}

	// Create a new PR
	err = ghcli.RunGHWithStdout("pr", "create", "-R", ctx.GHRepository,
		"--base", branch,
		"--head", cherryPickBranch,
		"--title", fmt.Sprintf("[%s] %s", branch, prTitle),
		"--body", fmt.Sprintf("Cherry-pick of #%s to `%s`.", ctx.IssueNumber, branch))
	if err != nil {
		return fmt.Errorf("Failed to create the cherry-pick PR.")
	}

	return nil
}

// --- Label commands ---

func labelCmd(ctx *Context, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Missing required argument: label name.")
	}
	label := strings.Join(args, ",")
	fmt.Printf("Add label %s to %s#%s\n", label, ctx.GHRepository, ctx.IssueNumber)
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, label)
}

func removeLabelCmd(ctx *Context, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Missing required argument: label name.")
	}
	label := strings.Join(args, ",")
	fmt.Printf("Remove label %s to %s#%s\n", label, ctx.GHRepository, ctx.IssueNumber)
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, label)
}

// --- Label category commands ---

func approveCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	if ctx.Login == ctx.Author {
		return fmt.Errorf("You cannot approve your own PR. Please ask another reviewer to approve it.")
	}
	fmt.Printf("Add label approved to %s#%s\n", ctx.GHRepository, ctx.IssueNumber)
	if err := ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "approved"); err != nil {
		return err
	}
	return ghcli.CheckAutoMerge(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, ctx.Login)
}

func removeApproveCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	fmt.Printf("Remove label approved to %s#%s\n", ctx.GHRepository, ctx.IssueNumber)
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "approved")
}

func bugCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "bug")
}

func removeBugCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "bug")
}

func documentationCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "documentation")
}

func removeDocumentationCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "documentation")
}

func duplicateCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "duplicate")
}

func removeDuplicateCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "duplicate")
}

func enhancementCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "enhancement")
}

func removeEnhancementCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "enhancement")
}

func goodFirstIssueCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "good first issue")
}

func removeGoodFirstIssueCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "good first issue")
}

func helpWantedCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "help wanted")
}

func removeHelpWantedCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "help wanted")
}

func invalidCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "invalid")
}

func removeInvalidCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "invalid")
}

func kindCmd(ctx *Context, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Missing required argument: kind name. Usage: `/kind <name>`")
	}
	labels := make([]string, len(args))
	for i, a := range args {
		labels[i] = "kind/" + a
	}
	label := strings.Join(labels, ",")
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, label)
}

func removeKindCmd(ctx *Context, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Missing required argument: kind name. Usage: `/remove-kind <name>`")
	}
	labels := make([]string, len(args))
	for i, a := range args {
		labels[i] = "kind/" + a
	}
	label := strings.Join(labels, ",")
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, label)
}

func lgtmCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	if ctx.Login == ctx.Author {
		return fmt.Errorf("You cannot LGTM your own PR. Please ask another reviewer to approve it.")
	}
	fmt.Printf("Add label lgtm to %s#%s\n", ctx.GHRepository, ctx.IssueNumber)
	if err := ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "lgtm"); err != nil {
		return err
	}
	return ghcli.CheckAutoMerge(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, ctx.Login)
}

func removeLgtmCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	fmt.Printf("Remove label lgtm to %s#%s\n", ctx.GHRepository, ctx.IssueNumber)
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "lgtm")
}

func questionCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "question")
}

func removeQuestionCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "question")
}

func wontfixCmd(ctx *Context, args []string) error {
	return ghcli.AddLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "wontfix")
}

func removeWontfixCmd(ctx *Context, args []string) error {
	return ghcli.RemoveLabels(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "wontfix")
}

// --- Lifecycle commands ---

func closeCmd(ctx *Context, args []string) error {
	return ghcli.Close(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber)
}

func reopenCmd(ctx *Context, args []string) error {
	return ghcli.Reopen(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber)
}

// --- Merge command ---

func mergeCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	strategy := ""
	if len(args) > 0 {
		strategy = args[0]
	}
	return ghcli.PRMerge(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, ctx.Login, strategy)
}

// --- Milestone commands ---

func milestoneCmd(ctx *Context, args []string) error {
	if len(args) == 0 || args[0] == "" {
		return fmt.Errorf("Missing required argument: milestone name. Usage: `/milestone <name>`")
	}
	fmt.Printf("Setting milestone to %s\n", args[0])
	return ghcli.SetMilestone(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, args[0])
}

func removeMilestoneCmd(ctx *Context, args []string) error {
	fmt.Println("Setting milestone to ")
	return ghcli.SetMilestone(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, "")
}

// --- Rebase command ---

func rebaseCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}
	return ghcli.UpdateBranchRebase(ctx.GHRepository, ctx.IssueNumber)
}

// --- Retest command ---

func retestCmd(ctx *Context, args []string) error {
	if err := requirePR(ctx); err != nil {
		return err
	}

	// Get PR head SHA
	headSHA, err := ghcli.RunGH("api",
		"-H", "Accept: application/vnd.github+json",
		fmt.Sprintf("/repos/%s/pulls/%s", ctx.GHRepository, ctx.IssueNumber),
		"--jq", ".head.sha")
	if err != nil {
		return fmt.Errorf("Failed to get PR head SHA.")
	}

	// Get check suites
	checkSuitesJSON, err := ghcli.RunGH("api",
		"-H", "Accept: application/vnd.github+json",
		fmt.Sprintf("/repos/%s/commits/%s/check-suites?per_page=100", ctx.GHRepository, headSHA))
	if err != nil {
		return fmt.Errorf("Failed to get check suites.")
	}

	var checkSuites struct {
		CheckSuites []struct {
			ID         int    `json:"id"`
			Conclusion string `json:"conclusion"`
		} `json:"check_suites"`
	}
	if err := json.Unmarshal([]byte(checkSuitesJSON), &checkSuites); err != nil {
		return fmt.Errorf("Failed to parse check suites.")
	}

	var failed []string
	for _, suite := range checkSuites.CheckSuites {
		if suite.Conclusion != "failure" {
			continue
		}

		// Get workflow runs for this check suite
		runsJSON, err := ghcli.RunGH("api",
			"-H", "Accept: application/vnd.github+json",
			fmt.Sprintf("/repos/%s/actions/runs?status=failure&per_page=100&check_suite_id=%d", ctx.GHRepository, suite.ID))
		if err != nil {
			continue
		}

		var runs struct {
			WorkflowRuns []struct {
				ID         int    `json:"id"`
				Conclusion string `json:"conclusion"`
			} `json:"workflow_runs"`
		}
		if err := json.Unmarshal([]byte(runsJSON), &runs); err != nil {
			continue
		}

		for _, run := range runs.WorkflowRuns {
			if run.Conclusion != "failure" {
				continue
			}
			fmt.Printf("Check suite ID: %d\n", suite.ID)
			fmt.Printf("Workflow run ID: %d\n", run.ID)
			_, err := ghcli.RunGH("api",
				"--method", "POST",
				"-H", "Accept: application/vnd.github+json",
				fmt.Sprintf("/repos/%s/actions/runs/%d/rerun-failed-jobs", ctx.GHRepository, run.ID))
			if err != nil {
				failed = append(failed, fmt.Sprintf("https://github.com/%s/actions/runs/%d", ctx.GHRepository, run.ID))
			}
		}
	}

	if len(failed) == 0 {
		fmt.Println("All were re-requested")
	} else {
		fmt.Println("Failed to re-request:")
		for _, f := range failed {
			fmt.Printf("  - %s\n", f)
		}
	}
	return nil
}

// --- Retitle command ---

func retitleCmd(ctx *Context, args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("Missing required argument: title. Usage: `/retitle <new title>`")
	}
	title := strings.Join(args, " ")
	return ghcli.EditTitle(ctx.IssueKind, ctx.GHRepository, ctx.IssueNumber, title)
}

// --- YAML helper for auto-cc ---

// ResolveEnabledPlugins determines which plugin groups are enabled for the current user.
func ResolveEnabledPlugins(login, author, authorAssociation string, reviewers, approvers, maintainers []string, envPlugins map[string]string) map[string]bool {
	enabled := make(map[string]bool)

	// Base plugins - available to everyone
	for _, p := range parsePluginList(envPlugins["PLUGINS"]) {
		enabled[p] = true
	}

	// Author plugins
	if login == author && envPlugins["AUTHOR_PLUGINS"] != "" {
		fmt.Printf("%s is author\n", login)
		for _, p := range parsePluginList(envPlugins["AUTHOR_PLUGINS"]) {
			enabled[p] = true
		}
	}

	// Members plugins (and higher roles)
	if login != "" && authorAssociation != "NONE" && authorAssociation != "" {
		fmt.Printf("%s is a member\n", login)
		for _, p := range parsePluginList(envPlugins["MEMBERS_PLUGINS"]) {
			enabled[p] = true
		}

		// Reviewer plugins
		if len(reviewers) > 0 && envPlugins["REVIEWERS_PLUGINS"] != "" && contains(reviewers, login) {
			fmt.Printf("%s is a reviewer\n", login)
			for _, p := range parsePluginList(envPlugins["REVIEWERS_PLUGINS"]) {
				enabled[p] = true
			}
		}

		// Approver plugins
		if len(approvers) > 0 && envPlugins["APPROVERS_PLUGINS"] != "" && contains(approvers, login) {
			fmt.Printf("%s is a approver\n", login)
			for _, p := range parsePluginList(envPlugins["APPROVERS_PLUGINS"]) {
				enabled[p] = true
			}
		}

		// Maintainer plugins
		if len(maintainers) > 0 && envPlugins["MAINTAINERS_PLUGINS"] != "" && contains(maintainers, login) {
			fmt.Printf("%s is a maintainer\n", login)
			for _, p := range parsePluginList(envPlugins["MAINTAINERS_PLUGINS"]) {
				enabled[p] = true
			}
		}

		// Owner plugins
		if authorAssociation == "OWNER" {
			fmt.Printf("%s is a owner\n", login)
			for _, p := range parsePluginList(envPlugins["OWNERS_PLUGINS"]) {
				enabled[p] = true
			}
		}
	}

	return enabled
}

func parsePluginList(s string) []string {
	var plugins []string
	for _, line := range strings.Split(s, "\n") {
		p := strings.TrimSpace(line)
		if p != "" {
			plugins = append(plugins, p)
		}
	}
	return plugins
}

func contains(list []string, item string) bool {
	for _, v := range list {
		if v == item {
			return true
		}
	}
	return false
}

// EnabledCommands returns the set of command names available from the enabled plugin groups.
func EnabledCommands(enabledPlugins map[string]bool) map[string]bool {
	cmds := make(map[string]bool)
	for pluginGroup, enabled := range enabledPlugins {
		if !enabled {
			continue
		}
		if commands, ok := PluginCommands[pluginGroup]; ok {
			for _, cmd := range commands {
				cmds[cmd] = true
			}
		}
	}
	return cmds
}

// SortedPluginList returns a sorted list of enabled plugin names.
func SortedPluginList(enabledPlugins map[string]bool) []string {
	var list []string
	for p, enabled := range enabledPlugins {
		if enabled {
			list = append(list, p)
		}
	}
	sort.Strings(list)
	return list
}
