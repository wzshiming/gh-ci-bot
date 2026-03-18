package ghcli

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
)

// RunGH runs a gh CLI command and returns its combined output.
func RunGH(args ...string) (string, error) {
	cmd := exec.Command("gh", args...)
	cmd.Stderr = os.Stderr
	out, err := cmd.Output()
	return strings.TrimSpace(string(out)), err
}

// RunGHWithStdout runs a gh CLI command with stdout/stderr connected to os.
func RunGHWithStdout(args ...string) error {
	cmd := exec.Command("gh", args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// RunGit runs a git CLI command in the given directory and returns its combined output.
func RunGit(dir string, args ...string) (string, error) {
	cmd := exec.Command("git", args...)
	if dir != "" {
		cmd.Dir = dir
	}
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	output := stdout.String() + stderr.String()
	// Mask GH_TOKEN in output
	ghToken := os.Getenv("GH_TOKEN")
	if ghToken != "" {
		output = strings.ReplaceAll(output, ghToken, "***")
	}
	if err != nil {
		return output, fmt.Errorf("%s: %w", strings.TrimSpace(output), err)
	}
	return output, nil
}

// Comment posts a comment on an issue or PR.
func Comment(issueKind, ghRepository, issueNumber, body string) error {
	return RunGHWithStdout(issueKind, "-R", ghRepository, "comment", issueNumber, "--body", body)
}

// AddLabels adds labels to an issue or PR.
func AddLabels(issueKind, ghRepository, issueNumber, labels string) error {
	err := RunGHWithStdout(issueKind, "-R", ghRepository, "edit", issueNumber, "--add-label", labels)
	if err != nil {
		return fmt.Errorf("Failed to add label `%s`. Please check that the label exists in the repository", labels)
	}
	return nil
}

// RemoveLabels removes labels from an issue or PR.
func RemoveLabels(issueKind, ghRepository, issueNumber, labels string) error {
	err := RunGHWithStdout(issueKind, "-R", ghRepository, "edit", issueNumber, "--remove-label", labels)
	if err != nil {
		return fmt.Errorf("Failed to remove label `%s`. The label may not be currently applied", labels)
	}
	return nil
}

// AddAssignees adds assignees via REST API.
// Uses REST API instead of gh CLI to avoid issues with uppercase usernames.
// See: https://github.com/wzshiming/gh-ci-bot/issues/26
func AddAssignees(ghRepository, issueNumber, ghToken string, logins []string) error {
	var errs []string
	for _, login := range logins {
		url := fmt.Sprintf("https://api.github.com/repos/%s/issues/%s/assignees", ghRepository, issueNumber)
		body, _ := json.Marshal(map[string][]string{"assignees": {login}})
		req, err := http.NewRequest("POST", url, bytes.NewReader(body))
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to assign %s. Please check that the username is correct.", login))
			continue
		}
		req.Header.Set("Accept", "application/vnd.github.v3+json")
		req.Header.Set("Authorization", "token "+ghToken)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to assign %s. Please check that the username is correct.", login))
			continue
		}
		resp.Body.Close()
	}
	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "\n"))
	}
	return nil
}

// RemoveAssignees removes assignees via REST API.
func RemoveAssignees(ghRepository, issueNumber, ghToken string, logins []string) error {
	var errs []string
	for _, login := range logins {
		url := fmt.Sprintf("https://api.github.com/repos/%s/issues/%s/assignees", ghRepository, issueNumber)
		body, _ := json.Marshal(map[string][]string{"assignees": {login}})
		req, err := http.NewRequest("DELETE", url, bytes.NewReader(body))
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to remove assignee %s. Please check that the username is correct.", login))
			continue
		}
		req.Header.Set("Accept", "application/vnd.github.v3+json")
		req.Header.Set("Authorization", "token "+ghToken)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to remove assignee %s. Please check that the username is correct.", login))
			continue
		}
		resp.Body.Close()
	}
	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "\n"))
	}
	return nil
}

// AddReviewers requests reviewers via REST API.
// Uses REST API to avoid fetching organizational teams unnecessarily.
// See: https://github.com/wzshiming/gh-ci-bot/issues/1
func AddReviewers(ghRepository, issueNumber, ghToken string, logins []string) error {
	var errs []string
	for _, login := range logins {
		url := fmt.Sprintf("https://api.github.com/repos/%s/pulls/%s/requested_reviewers", ghRepository, issueNumber)
		body, _ := json.Marshal(map[string]interface{}{
			"reviewers":      []string{login},
			"team_reviewers": []string{},
		})
		req, err := http.NewRequest("POST", url, bytes.NewReader(body))
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to request review from %s. Please check that the username is correct.", login))
			continue
		}
		req.Header.Set("Accept", "application/vnd.github.v3+json")
		req.Header.Set("Authorization", "token "+ghToken)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to request review from %s. Please check that the username is correct.", login))
			continue
		}
		resp.Body.Close()
	}
	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "\n"))
	}
	return nil
}

// RemoveReviewers removes reviewer requests via REST API.
func RemoveReviewers(ghRepository, issueNumber, ghToken string, logins []string) error {
	var errs []string
	for _, login := range logins {
		url := fmt.Sprintf("https://api.github.com/repos/%s/pulls/%s/requested_reviewers", ghRepository, issueNumber)
		body, _ := json.Marshal(map[string]interface{}{
			"reviewers":      []string{login},
			"team_reviewers": []string{},
		})
		req, err := http.NewRequest("DELETE", url, bytes.NewReader(body))
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to remove reviewer %s. Please check that the username is correct.", login))
			continue
		}
		req.Header.Set("Accept", "application/vnd.github.v3+json")
		req.Header.Set("Authorization", "token "+ghToken)
		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			errs = append(errs, fmt.Sprintf("Failed to remove reviewer %s. Please check that the username is correct.", login))
			continue
		}
		resp.Body.Close()
	}
	if len(errs) > 0 {
		return fmt.Errorf("%s", strings.Join(errs, "\n"))
	}
	return nil
}

// SetMilestone sets or clears the milestone on an issue or PR.
func SetMilestone(issueKind, ghRepository, issueNumber, milestone string) error {
	err := RunGHWithStdout(issueKind, "-R", ghRepository, "edit", issueNumber, "--milestone", milestone)
	if err != nil {
		return fmt.Errorf("Failed to set milestone `%s`. Please check that the milestone exists in the repository", milestone)
	}
	return nil
}

// PRMerge merges a PR with the given strategy.
func PRMerge(issueKind, ghRepository, issueNumber, login, strategy string) error {
	args := "--merge"
	if strategy != "" {
		switch strategy {
		case "rebase":
			args = "--rebase"
		case "squash":
			args = "--squash"
		default:
			return fmt.Errorf("Invalid merge method: `%s`. Supported methods are: `rebase`, `squash`, or omit for default merge", strategy)
		}
	}
	fmt.Printf("PR %s#%s merge by %s\n", ghRepository, issueNumber, login)
	err := RunGHWithStdout(issueKind, "-R", ghRepository, "merge", issueNumber, "--auto", args)
	if err != nil {
		return fmt.Errorf("Failed to merge the PR. Please ensure all required checks have passed and there are no conflicts")
	}
	return nil
}

// CheckAutoMerge checks if a PR has both "lgtm" and "approved" labels and triggers auto-merge.
func CheckAutoMerge(issueKind, ghRepository, issueNumber, login string) error {
	if issueKind != "pr" {
		return nil
	}
	labelsStr, err := RunGH("pr", "-R", ghRepository, "view", issueNumber, "--json", "labels", "--jq", ".labels[].name")
	if err != nil {
		return nil
	}
	hasLgtm := false
	hasApproved := false
	for _, label := range strings.Split(labelsStr, "\n") {
		label = strings.TrimSpace(label)
		if label == "lgtm" {
			hasLgtm = true
		}
		if label == "approved" {
			hasApproved = true
		}
	}
	if hasLgtm && hasApproved {
		fmt.Println("PR has both 'lgtm' and 'approved' labels. Auto-merging.")
		return PRMerge(issueKind, ghRepository, issueNumber, login, "")
	}
	return nil
}

// Close closes an issue or PR.
func Close(issueKind, ghRepository, issueNumber string) error {
	return RunGHWithStdout(issueKind, "-R", ghRepository, "close", issueNumber)
}

// Reopen reopens an issue or PR.
func Reopen(issueKind, ghRepository, issueNumber string) error {
	return RunGHWithStdout(issueKind, "-R", ghRepository, "reopen", issueNumber)
}

// EditTitle edits the title of an issue or PR.
func EditTitle(issueKind, ghRepository, issueNumber, title string) error {
	return RunGHWithStdout(issueKind, "-R", ghRepository, "edit", issueNumber, "--title", title)
}

// EditBase changes the base branch of a PR.
func EditBase(ghRepository, issueNumber, branch string) error {
	err := RunGHWithStdout("-R", ghRepository, "pr", "edit", issueNumber, "-B", branch)
	if err != nil {
		return fmt.Errorf("Failed to change the base branch. Please verify the branch name exists and try again")
	}
	return nil
}

// UpdateBranchRebase rebases a PR branch.
func UpdateBranchRebase(ghRepository, issueNumber string) error {
	err := RunGHWithStdout("pr", "-R", ghRepository, "update-branch", issueNumber, "--rebase")
	if err != nil {
		return fmt.Errorf("Failed to rebase the branch. The branch may have conflicts that need to be resolved manually")
	}
	return nil
}

// BotLogin returns the authenticated bot's login name.
func BotLogin() string {
	login, err := RunGH("api", "/user", "--jq", ".login")
	if err != nil || login == "" || login == "null" {
		return "github-actions[bot]"
	}
	return login
}

// ClearComments deletes all comments by the bot on the given issue/PR.
func ClearComments(ghRepository, issueNumber string) error {
	botLogin := BotLogin()
	commentsJSON, err := RunGH("api", fmt.Sprintf("/repos/%s/issues/%s/comments", ghRepository, issueNumber))
	if err != nil {
		return err
	}
	var comments []struct {
		ID   int `json:"id"`
		User struct {
			Login string `json:"login"`
		} `json:"user"`
	}
	if err := json.Unmarshal([]byte(commentsJSON), &comments); err != nil {
		return err
	}
	for _, c := range comments {
		if c.User.Login == botLogin {
			_, _ = RunGH("api", fmt.Sprintf("/repos/%s/issues/comments/%d", ghRepository, c.ID), "--silent", "-X", "DELETE")
		}
	}
	return nil
}

// FetchURL fetches the content at the given URL.
func FetchURL(url string) (string, error) {
	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d for %s", resp.StatusCode, url)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", err
	}
	return string(body), nil
}

// GetDefaultBranch returns the default branch of the repository.
func GetDefaultBranch(ghRepository string) string {
	branch, err := RunGH("api", fmt.Sprintf("/repos/%s", ghRepository), "--jq", ".default_branch")
	if err != nil || branch == "" {
		return "main"
	}
	return branch
}
