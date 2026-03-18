package command

import (
	"reflect"
	"testing"
)

func TestClearComment(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "no comments",
			input: "hello world",
			want:  "hello world",
		},
		{
			name:  "single line comment",
			input: "before <!-- comment --> after",
			want:  "before COMMENT after",
		},
		{
			name:  "multi-line comment",
			input: "before\n<!-- multi\nline\ncomment -->\nafter",
			want:  "before\nCOMMENT\nafter",
		},
		{
			name:  "multiple comments",
			input: "a <!-- c1 --> b <!-- c2 --> c",
			want:  "a COMMENT b COMMENT c",
		},
		{
			name:  "command inside comment should be removed",
			input: "<!-- /assign @user -->\n/bug",
			want:  "COMMENT\n/bug",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ClearComment(tt.input)
			if got != tt.want {
				t.Errorf("ClearComment() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestExtractCommands(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  []string
	}{
		{
			name:  "no commands",
			input: "just some text\nwithout commands",
			want:  nil,
		},
		{
			name:  "single command",
			input: "/assign @user",
			want:  []string{"/assign @user"},
		},
		{
			name:  "multiple commands",
			input: "some text\n/bug\n/assign @user\nmore text\n/lgtm",
			want:  []string{"/bug", "/assign @user", "/lgtm"},
		},
		{
			name:  "command must start with slash",
			input: "not /a command\n/real command",
			want:  []string{"/real command"},
		},
		{
			name:  "uppercase not matched",
			input: "/Assign @user",
			want:  nil,
		},
		{
			name:  "number after slash not matched",
			input: "/123 test",
			want:  nil,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ExtractCommands(tt.input)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("ExtractCommands() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestParseCommandLine(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		wantCmd  string
		wantArgs []string
	}{
		{
			name:     "simple command",
			input:    "/assign",
			wantCmd:  "assign",
			wantArgs: nil,
		},
		{
			name:     "command with args",
			input:    "/assign @user1 @user2",
			wantCmd:  "assign",
			wantArgs: []string{"@user1", "@user2"},
		},
		{
			name:     "tabs replaced",
			input:    "/kind\tdoc",
			wantCmd:  "kind",
			wantArgs: []string{"doc"},
		},
		{
			name:     "multiple spaces collapsed",
			input:    "/label   bug   doc",
			wantCmd:  "label",
			wantArgs: []string{"bug", "doc"},
		},
		{
			name:     "carriage return removed",
			input:    "/bug\r",
			wantCmd:  "bug",
			wantArgs: nil,
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cmd, args := ParseCommandLine(tt.input)
			if cmd != tt.wantCmd {
				t.Errorf("ParseCommandLine() cmd = %q, want %q", cmd, tt.wantCmd)
			}
			if !reflect.DeepEqual(args, tt.wantArgs) {
				t.Errorf("ParseCommandLine() args = %v, want %v", args, tt.wantArgs)
			}
		})
	}
}
