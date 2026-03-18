package owners

import (
	"fmt"
	"io"
	"net/http"
	"sort"
	"strings"

	"gopkg.in/yaml.v3"
)

// OwnersFile represents the structure of an OWNERS file.
type OwnersFile struct {
	Reviewers []string `yaml:"reviewers"`
	Approvers []string `yaml:"approvers"`
}

// OwnersData holds the collected reviewers and approvers from OWNERS files.
type OwnersData struct {
	Reviewers []string
	Approvers []string
}

// GetCommonPrefix computes the longest common directory prefix of all files.
func GetCommonPrefix(files []string) string {
	if len(files) == 0 {
		return ""
	}

	prefix := ""
	first := true

	for _, f := range files {
		dir := ""
		if idx := strings.LastIndex(f, "/"); idx >= 0 {
			dir = f[:idx]
		}

		if first {
			prefix = dir
			first = false
			continue
		}

		// Find common prefix between current prefix and this dir
		for prefix != "" && dir != prefix && !strings.HasPrefix(dir, prefix+"/") {
			if idx := strings.LastIndex(prefix, "/"); idx >= 0 {
				prefix = prefix[:idx]
			} else {
				prefix = ""
			}
		}
	}

	return prefix
}

// FetchOwnersFile fetches an OWNERS file from the given directory in the repo.
func FetchOwnersFile(ghRepository, branch, dir string) (*OwnersFile, error) {
	path := "OWNERS"
	if dir != "" {
		path = dir + "/OWNERS"
	}
	url := fmt.Sprintf("https://github.com/%s/raw/%s/%s", ghRepository, branch, path)
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("not found")
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}
	var owners OwnersFile
	if err := yaml.Unmarshal(body, &owners); err != nil {
		return nil, err
	}
	return &owners, nil
}

// CollectOwnersFromPrefix walks from the given directory up to the root,
// collecting reviewers and approvers from every OWNERS file found.
func CollectOwnersFromPrefix(ghRepository, branch, dir string) *OwnersData {
	data := &OwnersData{}
	reviewersSet := make(map[string]bool)
	approversSet := make(map[string]bool)

	current := dir
	for {
		owners, err := FetchOwnersFile(ghRepository, branch, current)
		if err == nil && owners != nil {
			for _, r := range owners.Reviewers {
				reviewersSet[r] = true
			}
			for _, a := range owners.Approvers {
				approversSet[a] = true
			}
		}

		if current == "" {
			break
		}

		if idx := strings.LastIndex(current, "/"); idx >= 0 {
			current = current[:idx]
		} else {
			current = ""
		}
	}

	for r := range reviewersSet {
		data.Reviewers = append(data.Reviewers, r)
	}
	for a := range approversSet {
		data.Approvers = append(data.Approvers, a)
	}
	sort.Strings(data.Reviewers)
	sort.Strings(data.Approvers)
	return data
}

// GetPRChangedFiles fetches the list of changed files for a PR.
func GetPRChangedFiles(ghRepository, issueNumber string) ([]string, error) {
	url := fmt.Sprintf("https://github.com/%s/pull/%s.patch", ghRepository, issueNumber)
	resp, err := http.Get(url)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch patch: HTTP %d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	filesSet := make(map[string]bool)
	for _, line := range strings.Split(string(body), "\n") {
		if strings.HasPrefix(line, "--- a/") {
			filesSet[strings.TrimPrefix(line, "--- a/")] = true
		} else if strings.HasPrefix(line, "+++ b/") {
			filesSet[strings.TrimPrefix(line, "+++ b/")] = true
		}
	}

	var files []string
	for f := range filesSet {
		files = append(files, f)
	}
	sort.Strings(files)
	return files, nil
}

// MergeUnique merges two string slices and returns unique sorted values.
func MergeUnique(a, b []string) []string {
	set := make(map[string]bool)
	for _, s := range a {
		if s != "" {
			set[s] = true
		}
	}
	for _, s := range b {
		if s != "" {
			set[s] = true
		}
	}
	var result []string
	for s := range set {
		result = append(result, s)
	}
	sort.Strings(result)
	return result
}

// LoadOwnersForPR loads OWNERS data for a PR and merges with existing reviewers/approvers.
func LoadOwnersForPR(ghRepository, issueNumber, branch string, existingReviewers, existingApprovers []string) ([]string, []string) {
	files, err := GetPRChangedFiles(ghRepository, issueNumber)
	if err != nil {
		fmt.Fprintf(io.Discard, "Failed to get PR changed files: %v\n", err)
		return existingReviewers, existingApprovers
	}

	prefix := GetCommonPrefix(files)
	fmt.Printf("OWNERS: common prefix of changed files: '%s'\n", prefix)

	data := CollectOwnersFromPrefix(ghRepository, branch, prefix)

	if len(data.Reviewers) > 0 {
		fmt.Println("OWNERS reviewers:")
		for _, u := range data.Reviewers {
			fmt.Printf("  - %s\n", u)
		}
	}
	if len(data.Approvers) > 0 {
		fmt.Println("OWNERS approvers:")
		for _, u := range data.Approvers {
			fmt.Printf("  - %s\n", u)
		}
	}

	mergedReviewers := MergeUnique(existingReviewers, data.Reviewers)
	mergedApprovers := MergeUnique(existingApprovers, data.Approvers)

	return mergedReviewers, mergedApprovers
}
