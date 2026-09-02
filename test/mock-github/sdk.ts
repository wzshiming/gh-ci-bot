// SDK around the mock GitHub API server.
//
// gh redirection: with GH_HOST=github.localhost, gh talks plain HTTP to
// http://api.github.localhost/ (no /api/v3 prefix, no TLS), and
// *.localhost resolves to 127.0.0.1 — so a server on 127.0.0.1:80
// receives every gh request untouched. A port-suffixed GH_HOST would
// degrade to https GHE mode, so when port 80 cannot be bound (locally,
// without `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=80`) the
// SDK falls back to routing gh through a unix socket via the
// http_unix_socket setting in a generated GH_CONFIG_DIR. curl-based
// scripts reach the server through GITHUB_API_URL either way.

import http from "node:http";
import { once } from "node:events";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";

import type { MockRequest, RouteContext } from "./routes.ts";
import { dispatch } from "./routes.ts";
import type {
  MockComment,
  MockIssue,
  MockState,
  MockUser,
} from "./state.ts";
import { createState, getRepo, repoKey } from "./state.ts";

export interface RecordedRequest {
  method: string;
  path: string;
  query: Record<string, string>;
  headers: Record<string, string>;
  body: string;
  // Body parsed as JSON, when it parses.
  json?: unknown;
  status: number;
  // Matched route name, or null for a request no route handled — those
  // surface API coverage gaps in the scripts under test.
  route: string | null;
}

export interface MockGitHubOptions {
  // Token expected in the Authorization header. Defaults to "test-token".
  token?: string;
  // Upper bound applied to per_page, like the real API's cap of 100.
  // Lower it to exercise Link-header pagination with small fixtures.
  maxPerPage?: number;
}

export interface SeedRepoOptions {
  defaultBranch?: string;
}

export interface SeedIssueOptions {
  title?: string;
  body?: string;
  author?: string;
  assignees?: string[];
  labels?: string[];
}

export interface SeedPullOptions extends SeedIssueOptions {
  files?: string[];
}

export interface SeedCommentOptions {
  user?: string;
}

const GH_HOST = "github.localhost";
const API_HOST = "api.github.localhost";

function splitRepo(full: string): [string, string] {
  const at = full.indexOf("/");
  if (at <= 0 || at === full.length - 1) {
    throw new Error(`repository must be "owner/name", got "${full}"`);
  }
  return [full.slice(0, at), full.slice(at + 1)];
}

async function readBody(req: http.IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(chunk as Buffer);
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function listenOn(
  server: http.Server,
  where: { port?: number; host?: string; socketPath?: string },
): Promise<void> {
  const failed = new Promise<never>((_, reject) => {
    server.once("error", reject);
  });
  if (where.socketPath !== undefined) {
    server.listen(where.socketPath);
  } else {
    server.listen(where.port, where.host);
  }
  await Promise.race([once(server, "listening"), failed]);
}

export class MockGitHub {
  readonly token: string;

  private readonly maxPerPage: number;
  private state: MockState = createState();
  private log: RecordedRequest[] = [];

  private tcpServer: http.Server | null = null;
  private socketServer: http.Server | null = null;
  private port = 0;
  private tempDir: string | null = null;
  private configDir: string | null = null;

  constructor(options: MockGitHubOptions = {}) {
    this.token = options.token ?? "test-token";
    this.maxPerPage = options.maxPerPage ?? 100;
  }

  // listen starts the server on 127.0.0.1:80, falling back to an
  // ephemeral port plus a unix socket for gh when 80 is not bindable.
  async listen(): Promise<void> {
    if (this.tcpServer) {
      throw new Error("mock server is already listening");
    }
    this.tempDir = await fs.mkdtemp(path.join(os.tmpdir(), "mock-github-"));
    this.configDir = path.join(this.tempDir, "gh-config");
    await fs.mkdir(this.configDir);

    const server = http.createServer((req, res) => {
      void this.handle(req, res);
    });
    try {
      await listenOn(server, { port: 80, host: "127.0.0.1" });
      this.port = 80;
    } catch (error) {
      const code = (error as NodeJS.ErrnoException).code;
      if (code !== "EACCES" && code !== "EPERM" && code !== "EADDRINUSE") {
        throw error;
      }
      await listenOn(server, { port: 0, host: "127.0.0.1" });
      const address = server.address();
      if (address === null || typeof address !== "object") {
        throw new Error("mock server has no TCP address");
      }
      this.port = address.port;

      // gh cannot reach a port-suffixed host over plain HTTP, so point it
      // at a unix socket serving the same handler instead.
      const socketPath = path.join(this.tempDir, "api.sock");
      this.socketServer = http.createServer((req, res) => {
        void this.handle(req, res);
      });
      await listenOn(this.socketServer, { socketPath });
      await fs.writeFile(
        path.join(this.configDir, "config.yml"),
        `http_unix_socket: ${socketPath}\n`,
      );
    }
    this.tcpServer = server;
  }

  async close(): Promise<void> {
    for (const server of [this.tcpServer, this.socketServer]) {
      if (!server) {
        continue;
      }
      server.closeAllConnections();
      await new Promise<void>((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }
    this.tcpServer = null;
    this.socketServer = null;
    this.port = 0;
    if (this.tempDir) {
      await fs.rm(this.tempDir, { recursive: true, force: true });
      this.tempDir = null;
      this.configDir = null;
    }
  }

  // apiUrl is the plain-HTTP base URL of the server, for curl-based
  // scripts via GITHUB_API_URL.
  get apiUrl(): string {
    if (!this.tcpServer) {
      throw new Error("mock server is not listening");
    }
    return this.port === 80
      ? `http://${API_HOST}`
      : `http://${API_HOST}:${this.port}`;
  }

  // env returns the environment that redirects gh and the curl-based
  // scripts to this server. Spread it into the child process env.
  env(): Record<string, string> {
    if (!this.configDir) {
      throw new Error("mock server is not listening");
    }
    return {
      GH_HOST,
      GH_TOKEN: this.token,
      GITHUB_API_URL: this.apiUrl,
      // Isolated config dir: keeps the developer's real gh config out of
      // the tests and carries http_unix_socket in fallback mode.
      GH_CONFIG_DIR: this.configDir,
      GH_PROMPT_DISABLED: "1",
      GH_NO_UPDATE_NOTIFIER: "1",
      NO_COLOR: "1",
    };
  }

  // reset drops all seeded state and the request log, so a test starts
  // from a clean slate without restarting the server.
  reset(): void {
    this.state = createState();
    this.log = [];
  }

  get requests(): readonly RecordedRequest[] {
    return this.log;
  }

  get unmatchedRequests(): readonly RecordedRequest[] {
    return this.log.filter((entry) => entry.route === null);
  }

  clearRequests(): void {
    this.log = [];
  }

  // seedUser sets the user identified by the token (GET /user, comment
  // author). Without it the server mimics an installation token.
  seedUser(login: string): void {
    this.state.viewer = { login };
  }

  seedRepo(full: string, options: SeedRepoOptions = {}): void {
    const [owner, name] = splitRepo(full);
    this.state.repos.set(repoKey(owner, name), {
      owner,
      name,
      defaultBranch: options.defaultBranch ?? "main",
      issues: new Map(),
      comments: new Map(),
      contents: new Map(),
      pullFiles: new Map(),
    });
  }

  seedIssue(full: string, number: number, options: SeedIssueOptions = {}): void {
    this.seedIssueLike(full, number, "issue", options);
  }

  seedPull(full: string, number: number, options: SeedPullOptions = {}): void {
    const repo = this.seedIssueLike(full, number, "pr", options);
    repo.pullFiles.set(
      number,
      (options.files ?? []).map((filename) => ({
        filename,
        status: "modified",
        additions: 1,
        deletions: 1,
        changes: 2,
      })),
    );
  }

  seedComment(
    full: string,
    issueNumber: number,
    body: string,
    options: SeedCommentOptions = {},
  ): number {
    const { repo, issue } = this.requireIssue(full, issueNumber);
    const now = new Date().toISOString();
    const comment: MockComment = {
      id: this.state.nextCommentId++,
      body,
      user: { login: options.user ?? this.state.viewer?.login ?? "octocat" },
      created_at: now,
      updated_at: now,
    };
    repo.comments.set(comment.id, comment);
    issue.commentIds.push(comment.id);
    return comment.id;
  }

  // seedContent stores a file at the given ref (default branch when
  // omitted), served by GET /repos/{owner}/{repo}/contents/{path}.
  seedContent(
    full: string,
    filePath: string,
    content: string,
    ref?: string,
  ): void {
    const repo = this.requireRepo(full);
    const target = ref ?? repo.defaultBranch;
    let files = repo.contents.get(target);
    if (!files) {
      files = new Map();
      repo.contents.set(target, files);
    }
    files.set(filePath, content);
  }

  getIssue(full: string, number: number): MockIssue {
    return this.requireIssue(full, number).issue;
  }

  listComments(full: string, issueNumber: number): MockComment[] {
    const { repo, issue } = this.requireIssue(full, issueNumber);
    return issue.commentIds
      .map((id) => repo.comments.get(id))
      .filter((comment): comment is MockComment => comment !== undefined);
  }

  private seedIssueLike(
    full: string,
    number: number,
    kind: "issue" | "pr",
    options: SeedIssueOptions,
  ) {
    const repo = this.requireRepo(full);
    const issue: MockIssue = {
      number,
      kind,
      title: options.title ?? `${kind} ${number}`,
      body: options.body ?? "",
      state: "open",
      user: { login: options.author ?? "octocat" },
      assignees: (options.assignees ?? []).map(
        (login): MockUser => ({ login }),
      ),
      labels: (options.labels ?? []).map((name) => ({ name })),
      commentIds: [],
    };
    repo.issues.set(number, issue);
    return repo;
  }

  private requireRepo(full: string) {
    const [owner, name] = splitRepo(full);
    const repo = getRepo(this.state, owner, name);
    if (!repo) {
      throw new Error(`repository ${full} is not seeded`);
    }
    return repo;
  }

  private requireIssue(full: string, number: number) {
    const repo = this.requireRepo(full);
    const issue = repo.issues.get(number);
    if (!issue) {
      throw new Error(`issue ${full}#${number} is not seeded`);
    }
    return { repo, issue };
  }

  private async handle(
    req: http.IncomingMessage,
    res: http.ServerResponse,
  ): Promise<void> {
    const body = await readBody(req);
    const url = new URL(req.url ?? "/", `http://${API_HOST}`);

    let json: unknown;
    if (body !== "") {
      try {
        json = JSON.parse(body);
      } catch {
        json = undefined;
      }
    }

    const request: MockRequest = {
      method: req.method ?? "GET",
      path: decodeURIComponent(url.pathname),
      query: url.searchParams,
      headers: req.headers,
      body,
      json,
    };
    const ctx: RouteContext = {
      maxPerPage: this.maxPerPage,
      baseUrl: `http://${req.headers.host ?? API_HOST}`,
    };

    const authorization = String(req.headers.authorization ?? "");
    const authorized = ["token", "bearer"].some(
      (scheme) => authorization.toLowerCase() === `${scheme} ${this.token}`,
    );

    const { route, response } = authorized
      ? dispatch(this.state, request, ctx)
      : {
          route: null,
          response: {
            status: 401,
            headers: { "content-type": "application/json; charset=utf-8" },
            body: JSON.stringify({ message: "Bad credentials" }),
          },
        };

    this.log.push({
      method: request.method,
      path: request.path,
      query: Object.fromEntries(url.searchParams),
      headers: Object.fromEntries(
        Object.entries(req.headers).map(([key, value]) => [
          key,
          Array.isArray(value) ? value.join(", ") : (value ?? ""),
        ]),
      ),
      body,
      json,
      status: response.status,
      route,
    });

    res.writeHead(response.status, response.headers);
    res.end(response.body);
  }
}
