package owners

import (
	"reflect"
	"sort"
	"testing"
)

func TestGetCommonPrefix(t *testing.T) {
	tests := []struct {
		name  string
		files []string
		want  string
	}{
		{
			name:  "empty",
			files: nil,
			want:  "",
		},
		{
			name:  "single file at root",
			files: []string{"README.md"},
			want:  "",
		},
		{
			name:  "single file in directory",
			files: []string{"pkg/api/handler.go"},
			want:  "pkg/api",
		},
		{
			name:  "common prefix",
			files: []string{"pkg/api/handler.go", "pkg/util/helper.go"},
			want:  "pkg",
		},
		{
			name:  "same directory",
			files: []string{"pkg/api/a.go", "pkg/api/b.go"},
			want:  "pkg/api",
		},
		{
			name:  "root level files",
			files: []string{"a.go", "b.go"},
			want:  "",
		},
		{
			name:  "mixed root and nested",
			files: []string{"a.go", "pkg/b.go"},
			want:  "",
		},
		{
			name:  "deeply nested common prefix",
			files: []string{"a/b/c/d.go", "a/b/c/e.go"},
			want:  "a/b/c",
		},
		{
			name:  "partially common",
			files: []string{"a/b/c/d.go", "a/b/e/f.go"},
			want:  "a/b",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetCommonPrefix(tt.files)
			if got != tt.want {
				t.Errorf("GetCommonPrefix() = %q, want %q", got, tt.want)
			}
		})
	}
}

func TestMergeUnique(t *testing.T) {
	tests := []struct {
		name string
		a    []string
		b    []string
		want []string
	}{
		{
			name: "both empty",
			a:    nil,
			b:    nil,
			want: nil,
		},
		{
			name: "first empty",
			a:    nil,
			b:    []string{"user1"},
			want: []string{"user1"},
		},
		{
			name: "duplicates removed",
			a:    []string{"user1", "user2"},
			b:    []string{"user2", "user3"},
			want: []string{"user1", "user2", "user3"},
		},
		{
			name: "empty strings removed",
			a:    []string{"user1", ""},
			b:    []string{"", "user2"},
			want: []string{"user1", "user2"},
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := MergeUnique(tt.a, tt.b)
			sort.Strings(got)
			if !reflect.DeepEqual(got, tt.want) {
				t.Errorf("MergeUnique() = %v, want %v", got, tt.want)
			}
		})
	}
}
