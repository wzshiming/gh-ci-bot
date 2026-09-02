// In-memory state store for the mock GitHub API server.
//
// The store intentionally keeps only the fields the bin/ scripts read, so
// that responses stay small and assertions stay focused. Everything is
// plain data: routes.ts mutates it, the SDK seeds and inspects it.

export interface MockUser {
  login: string;
}

export interface MockLabel {
  name: string;
}

export interface MockComment {
  id: number;
  body: string;
  user: MockUser;
  created_at: string;
  updated_at: string;
}

export interface MockPullFile {
  filename: string;
  status: string;
  additions: number;
  deletions: number;
  changes: number;
}

export interface MockIssue {
  number: number;
  // "pr" makes the issue also visible through the pulls/* endpoints.
  kind: "issue" | "pr";
  title: string;
  body: string;
  state: "open" | "closed";
  user: MockUser;
  assignees: MockUser[];
  labels: MockLabel[];
  // Comment ids in creation order. Bodies live in MockRepo.comments since
  // the GitHub API addresses comments by repo, not by issue.
  commentIds: number[];
}

export interface MockRepo {
  owner: string;
  name: string;
  defaultBranch: string;
  issues: Map<number, MockIssue>;
  comments: Map<number, MockComment>;
  // ref -> path -> raw file content
  contents: Map<string, Map<string, string>>;
  // PR number -> changed files
  pullFiles: Map<number, MockPullFile[]>;
}

export interface MockState {
  // The user identified by the token. null mimics an installation token
  // such as GITHUB_TOKEN in Actions: GET /user fails and comments are
  // authored by github-actions[bot].
  viewer: MockUser | null;
  repos: Map<string, MockRepo>;
  nextCommentId: number;
}

// Login used to author comments when no viewer is seeded, mirroring how
// installation tokens show up on github.com.
export const INSTALLATION_LOGIN = "github-actions[bot]";

export function createState(): MockState {
  return {
    viewer: null,
    repos: new Map(),
    nextCommentId: 1,
  };
}

export function repoKey(owner: string, name: string): string {
  return `${owner}/${name}`;
}

export function getRepo(
  state: MockState,
  owner: string,
  name: string,
): MockRepo | undefined {
  return state.repos.get(repoKey(owner, name));
}

export function commentAuthor(state: MockState): MockUser {
  return state.viewer ?? { login: INSTALLATION_LOGIN };
}

export function createComment(
  state: MockState,
  repo: MockRepo,
  issue: MockIssue,
  body: string,
  user: MockUser = commentAuthor(state),
): MockComment {
  const now = new Date().toISOString();
  const comment: MockComment = {
    id: state.nextCommentId++,
    body,
    user,
    created_at: now,
    updated_at: now,
  };
  repo.comments.set(comment.id, comment);
  issue.commentIds.push(comment.id);
  return comment;
}

export function deleteComment(repo: MockRepo, id: number): boolean {
  if (!repo.comments.delete(id)) {
    return false;
  }
  for (const issue of repo.issues.values()) {
    const at = issue.commentIds.indexOf(id);
    if (at >= 0) {
      issue.commentIds.splice(at, 1);
    }
  }
  return true;
}
