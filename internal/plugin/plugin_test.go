package plugin

import (
	"sort"
	"testing"
)

func TestAllKnownCommands(t *testing.T) {
	known := AllKnownCommands()

	// Check that key commands exist
	expectedCmds := []string{
		"assign", "unassign", "auto-cc", "base", "cc", "uncc",
		"cherry-pick", "label", "remove-label",
		"approve", "remove-approve", "bug", "remove-bug",
		"lgtm", "remove-lgtm", "close", "reopen",
		"merge", "milestone", "remove-milestone",
		"rebase", "retest", "retitle",
		"kind", "remove-kind",
		"documentation", "remove-documentation",
		"duplicate", "remove-duplicate",
		"enhancement", "remove-enhancement",
		"good-first-issue", "remove-good-first-issue",
		"help-wanted", "remove-help-wanted",
		"invalid", "remove-invalid",
		"question", "remove-question",
		"wontfix", "remove-wontfix",
	}
	for _, cmd := range expectedCmds {
		if !known[cmd] {
			t.Errorf("expected command %q to be known", cmd)
		}
	}
}

func TestGetHandler(t *testing.T) {
	// All known commands should have handlers
	known := AllKnownCommands()
	for cmd := range known {
		handler := GetHandler(cmd)
		if handler == nil {
			t.Errorf("command %q has no handler", cmd)
		}
	}

	// Unknown commands should return nil
	if h := GetHandler("nonexistent"); h != nil {
		t.Error("expected nil handler for unknown command")
	}
}

func TestResolveEnabledPlugins(t *testing.T) {
	tests := []struct {
		name               string
		login              string
		author             string
		authorAssociation  string
		reviewers          []string
		approvers          []string
		maintainers        []string
		envPlugins         map[string]string
		wantPlugins        []string
	}{
		{
			name:              "base plugins only",
			login:             "user1",
			author:            "user2",
			authorAssociation: "NONE",
			envPlugins: map[string]string{
				"PLUGINS": "assign\nauto-cc\ncc",
			},
			wantPlugins: []string{"assign", "auto-cc", "cc"},
		},
		{
			name:              "author gets author plugins",
			login:             "user1",
			author:            "user1",
			authorAssociation: "NONE",
			envPlugins: map[string]string{
				"PLUGINS":        "assign",
				"AUTHOR_PLUGINS": "label-bug\nretest",
			},
			wantPlugins: []string{"assign", "label-bug", "retest"},
		},
		{
			name:              "member gets member plugins",
			login:             "user1",
			author:            "user2",
			authorAssociation: "MEMBER",
			envPlugins: map[string]string{
				"PLUGINS":         "assign",
				"MEMBERS_PLUGINS": "lifecycle\nlabel-kind",
			},
			wantPlugins: []string{"assign", "label-kind", "lifecycle"},
		},
		{
			name:              "reviewer gets reviewer plugins",
			login:             "user1",
			author:            "user2",
			authorAssociation: "MEMBER",
			reviewers:         []string{"user1", "user3"},
			envPlugins: map[string]string{
				"PLUGINS":           "assign",
				"MEMBERS_PLUGINS":   "lifecycle",
				"REVIEWERS_PLUGINS": "label-lgtm\nretitle",
			},
			wantPlugins: []string{"assign", "label-lgtm", "lifecycle", "retitle"},
		},
		{
			name:              "owner gets owner plugins",
			login:             "user1",
			author:            "user2",
			authorAssociation: "OWNER",
			envPlugins: map[string]string{
				"PLUGINS":        "assign",
				"MEMBERS_PLUGINS": "lifecycle",
				"OWNERS_PLUGINS": "merge",
			},
			wantPlugins: []string{"assign", "lifecycle", "merge"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			enabled := ResolveEnabledPlugins(
				tt.login, tt.author, tt.authorAssociation,
				tt.reviewers, tt.approvers, tt.maintainers,
				tt.envPlugins,
			)
			got := SortedPluginList(enabled)
			sort.Strings(tt.wantPlugins)
			if len(got) != len(tt.wantPlugins) {
				t.Errorf("got %v, want %v", got, tt.wantPlugins)
				return
			}
			for i, g := range got {
				if g != tt.wantPlugins[i] {
					t.Errorf("got %v, want %v", got, tt.wantPlugins)
					return
				}
			}
		})
	}
}

func TestEnabledCommands(t *testing.T) {
	enabled := map[string]bool{
		"assign":    true,
		"lifecycle": true,
	}
	cmds := EnabledCommands(enabled)

	expectedCmds := map[string]bool{
		"assign":   true,
		"unassign": true,
		"close":    true,
		"reopen":   true,
	}
	for cmd, want := range expectedCmds {
		if cmds[cmd] != want {
			t.Errorf("command %q: got %v, want %v", cmd, cmds[cmd], want)
		}
	}

	// Commands from disabled plugins should not be present
	if cmds["merge"] {
		t.Error("merge should not be enabled")
	}
}

func TestParseLogins(t *testing.T) {
	tests := []struct {
		name    string
		args    []string
		def     string
		want    []string
	}{
		{
			name: "no args uses default",
			args: nil,
			def:  "defaultuser",
			want: []string{"defaultuser"},
		},
		{
			name: "strips @",
			args: []string{"@user1", "@user2"},
			def:  "default",
			want: []string{"user1", "user2"},
		},
		{
			name: "no @ prefix",
			args: []string{"user1"},
			def:  "default",
			want: []string{"user1"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseLogins(tt.args, tt.def)
			if len(got) != len(tt.want) {
				t.Errorf("parseLogins() = %v, want %v", got, tt.want)
				return
			}
			for i, g := range got {
				if g != tt.want[i] {
					t.Errorf("parseLogins() = %v, want %v", got, tt.want)
					return
				}
			}
		})
	}
}

func TestStripAt(t *testing.T) {
	if got := stripAt("@user"); got != "user" {
		t.Errorf("stripAt(@user) = %q, want %q", got, "user")
	}
	if got := stripAt("user"); got != "user" {
		t.Errorf("stripAt(user) = %q, want %q", got, "user")
	}
}

func TestRequirePR(t *testing.T) {
	ctx := &Context{IssueKind: "issue"}
	if err := requirePR(ctx); err == nil {
		t.Error("expected error for issue kind")
	}

	ctx.IssueKind = "pr"
	if err := requirePR(ctx); err != nil {
		t.Errorf("unexpected error for pr kind: %v", err)
	}
}
