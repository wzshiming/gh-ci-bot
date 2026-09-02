// REST routes of the mock GitHub API server.
//
// Only the endpoints exercised by the pure-REST bin/ scripts are
// implemented (phase 1). Anything else falls through to a 404 that the
// server records as an unmatched request, so coverage gaps surface in
// tests instead of being silently swallowed.

import type {
  MockComment,
  MockIssue,
  MockRepo,
  MockState,
  MockUser,
} from "./state.ts";
import { createComment, deleteComment, getRepo } from "./state.ts";

export interface MockRequest {
  method: string;
  // Decoded pathname, e.g. "/repos/o/r/contents/a/OWNERS"
  path: string;
  query: URLSearchParams;
  headers: Record<string, string | string[] | undefined>;
  body: string;
  // Body parsed as JSON when possible (curl -d sends JSON without a JSON
  // content type, so parsing is attempted on every non-empty body).
  json: unknown;
}

export interface MockResponse {
  status: number;
  headers?: Record<string, string>;
  body?: string;
}

export interface RouteContext {
  // Upper bound on per_page, like the real API's cap of 100. Tests lower
  // it to exercise Link-header pagination with small fixtures.
  maxPerPage: number;
  // Base URL used in Link headers, derived from the request Host header.
  baseUrl: string;
}

interface Route {
  name: string;
  method: string;
  pattern: RegExp;
  handle: (
    state: MockState,
    req: MockRequest,
    params: string[],
    ctx: RouteContext,
  ) => MockResponse;
}

function json(status: number, value: unknown): MockResponse {
  return {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
    body: JSON.stringify(value),
  };
}

function notFound(): MockResponse {
  return json(404, {
    message: "Not Found",
    documentation_url: "https://docs.github.com/rest",
  });
}

function userJson(user: MockUser): unknown {
  return { login: user.login, type: "User" };
}

function repoJson(repo: MockRepo): unknown {
  return {
    name: repo.name,
    full_name: `${repo.owner}/${repo.name}`,
    owner: userJson({ login: repo.owner }),
    default_branch: repo.defaultBranch,
  };
}

function commentJson(comment: MockComment): unknown {
  return {
    id: comment.id,
    body: comment.body,
    user: userJson(comment.user),
    created_at: comment.created_at,
    updated_at: comment.updated_at,
  };
}

function issueJson(issue: MockIssue): unknown {
  return {
    number: issue.number,
    title: issue.title,
    body: issue.body,
    state: issue.state,
    user: userJson(issue.user),
    assignees: issue.assignees.map(userJson),
    labels: issue.labels.map((label) => ({ name: label.name })),
    ...(issue.kind === "pr" ? { pull_request: {} } : {}),
  };
}

// paginate slices items according to page/per_page and emits the same
// RFC 5988 Link header the real API uses, which `gh api --paginate`
// follows to fetch every page.
function paginate<T>(
  items: T[],
  req: MockRequest,
  ctx: RouteContext,
  render: (item: T) => unknown,
): MockResponse {
  const perPageParam = Number.parseInt(req.query.get("per_page") ?? "30", 10);
  const perPage = Math.min(
    Math.max(Number.isNaN(perPageParam) ? 30 : perPageParam, 1),
    ctx.maxPerPage,
  );
  const pageParam = Number.parseInt(req.query.get("page") ?? "1", 10);
  const page = Math.max(Number.isNaN(pageParam) ? 1 : pageParam, 1);
  const lastPage = Math.max(Math.ceil(items.length / perPage), 1);

  const pageUrl = (target: number): string => {
    const query = new URLSearchParams(req.query);
    query.set("per_page", String(perPage));
    query.set("page", String(target));
    return `${ctx.baseUrl}${req.path}?${query}`;
  };

  const links: string[] = [];
  if (page > 1) {
    links.push(`<${pageUrl(page - 1)}>; rel="prev"`);
    links.push(`<${pageUrl(1)}>; rel="first"`);
  }
  if (page < lastPage) {
    links.push(`<${pageUrl(page + 1)}>; rel="next"`);
    links.push(`<${pageUrl(lastPage)}>; rel="last"`);
  }

  const start = (page - 1) * perPage;
  const response = json(200, items.slice(start, start + perPage).map(render));
  if (links.length > 0) {
    response.headers = { ...response.headers, link: links.join(", ") };
  }
  return response;
}

function repoFrom(
  state: MockState,
  params: string[],
): MockRepo | undefined {
  return getRepo(state, params[0] ?? "", params[1] ?? "");
}

function issueFrom(
  state: MockState,
  params: string[],
): { repo: MockRepo; issue: MockIssue } | undefined {
  const repo = repoFrom(state, params);
  const issue = repo?.issues.get(Number(params[2]));
  if (!repo || !issue) {
    return undefined;
  }
  return { repo, issue };
}

function bodyField(req: MockRequest, field: string): unknown {
  if (typeof req.json !== "object" || req.json === null) {
    return undefined;
  }
  return (req.json as Record<string, unknown>)[field];
}

function stringArrayField(req: MockRequest, field: string): string[] {
  const value = bodyField(req, field);
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is string => typeof item === "string");
}

const routes: Route[] = [
  {
    name: "GET /user",
    method: "GET",
    pattern: /^\/user$/,
    handle: (state) => {
      if (!state.viewer) {
        // Mirrors GET /user with an installation token (GITHUB_TOKEN).
        return json(403, {
          message: "Resource not accessible by integration",
        });
      }
      return json(200, userJson(state.viewer));
    },
  },
  {
    name: "GET /repos/{owner}/{repo}",
    method: "GET",
    pattern: /^\/repos\/([^/]+)\/([^/]+)$/,
    handle: (state, _req, params) => {
      const repo = repoFrom(state, params);
      return repo ? json(200, repoJson(repo)) : notFound();
    },
  },
  {
    name: "GET /repos/{owner}/{repo}/issues/{number}/comments",
    method: "GET",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/(\d+)\/comments$/,
    handle: (state, req, params, ctx) => {
      const found = issueFrom(state, params);
      if (!found) {
        return notFound();
      }
      const comments = found.issue.commentIds
        .map((id) => found.repo.comments.get(id))
        .filter((comment): comment is MockComment => comment !== undefined);
      return paginate(comments, req, ctx, commentJson);
    },
  },
  {
    name: "POST /repos/{owner}/{repo}/issues/{number}/comments",
    method: "POST",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/(\d+)\/comments$/,
    handle: (state, req, params) => {
      const found = issueFrom(state, params);
      if (!found) {
        return notFound();
      }
      const body = bodyField(req, "body");
      if (typeof body !== "string") {
        return json(422, { message: "Invalid request. body is required." });
      }
      const comment = createComment(state, found.repo, found.issue, body);
      return json(201, commentJson(comment));
    },
  },
  {
    name: "GET /repos/{owner}/{repo}/issues/comments/{id}",
    method: "GET",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/comments\/(\d+)$/,
    handle: (state, _req, params) => {
      const comment = repoFrom(state, params)?.comments.get(Number(params[2]));
      return comment ? json(200, commentJson(comment)) : notFound();
    },
  },
  {
    name: "PATCH /repos/{owner}/{repo}/issues/comments/{id}",
    method: "PATCH",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/comments\/(\d+)$/,
    handle: (state, req, params) => {
      const comment = repoFrom(state, params)?.comments.get(Number(params[2]));
      if (!comment) {
        return notFound();
      }
      const body = bodyField(req, "body");
      if (typeof body !== "string") {
        return json(422, { message: "Invalid request. body is required." });
      }
      comment.body = body;
      comment.updated_at = new Date().toISOString();
      return json(200, commentJson(comment));
    },
  },
  {
    name: "DELETE /repos/{owner}/{repo}/issues/comments/{id}",
    method: "DELETE",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/comments\/(\d+)$/,
    handle: (state, _req, params) => {
      const repo = repoFrom(state, params);
      if (!repo || !deleteComment(repo, Number(params[2]))) {
        return notFound();
      }
      return { status: 204 };
    },
  },
  {
    name: "POST /repos/{owner}/{repo}/issues/{number}/assignees",
    method: "POST",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/(\d+)\/assignees$/,
    handle: (state, req, params) => {
      const found = issueFrom(state, params);
      if (!found) {
        return notFound();
      }
      for (const login of stringArrayField(req, "assignees")) {
        const known = found.issue.assignees.some(
          (assignee) => assignee.login.toLowerCase() === login.toLowerCase(),
        );
        if (!known) {
          found.issue.assignees.push({ login });
        }
      }
      return json(201, issueJson(found.issue));
    },
  },
  {
    name: "DELETE /repos/{owner}/{repo}/issues/{number}/assignees",
    method: "DELETE",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/issues\/(\d+)\/assignees$/,
    handle: (state, req, params) => {
      const found = issueFrom(state, params);
      if (!found) {
        return notFound();
      }
      const removed = new Set(
        stringArrayField(req, "assignees").map((login) => login.toLowerCase()),
      );
      found.issue.assignees = found.issue.assignees.filter(
        (assignee) => !removed.has(assignee.login.toLowerCase()),
      );
      return json(200, issueJson(found.issue));
    },
  },
  {
    name: "GET /repos/{owner}/{repo}/contents/{path}",
    method: "GET",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/contents\/(.+)$/,
    handle: (state, req, params) => {
      const repo = repoFrom(state, params);
      if (!repo) {
        return notFound();
      }
      const path = params[2] ?? "";
      const ref = req.query.get("ref") || repo.defaultBranch;
      const content = repo.contents.get(ref)?.get(path);
      if (content === undefined) {
        return notFound();
      }
      const accept = String(req.headers.accept ?? "");
      if (accept.includes("raw")) {
        return {
          status: 200,
          headers: {
            "content-type": "application/vnd.github.raw+json; charset=utf-8",
          },
          body: content,
        };
      }
      return json(200, {
        type: "file",
        name: path.split("/").pop(),
        path,
        encoding: "base64",
        content: Buffer.from(content, "utf8").toString("base64"),
      });
    },
  },
  {
    name: "GET /repos/{owner}/{repo}/pulls/{number}/files",
    method: "GET",
    pattern: /^\/repos\/([^/]+)\/([^/]+)\/pulls\/(\d+)\/files$/,
    handle: (state, req, params, ctx) => {
      const found = issueFrom(state, params);
      if (!found || found.issue.kind !== "pr") {
        return notFound();
      }
      const files = found.repo.pullFiles.get(found.issue.number) ?? [];
      return paginate(files, req, ctx, (file) => file);
    },
  },
];

export interface RouteResult {
  // Matched route name, or null when the request hit no known route (a
  // coverage gap surfaced as 404).
  route: string | null;
  response: MockResponse;
}

export function dispatch(
  state: MockState,
  req: MockRequest,
  ctx: RouteContext,
): RouteResult {
  for (const route of routes) {
    if (route.method !== req.method) {
      continue;
    }
    const match = req.path.match(route.pattern);
    if (!match) {
      continue;
    }
    return {
      route: route.name,
      response: route.handle(state, req, match.slice(1), ctx),
    };
  }
  return { route: null, response: notFound() };
}
