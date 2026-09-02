import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

import { MockGitHub } from "../mock-github/index.ts";
import { runBash } from "./helpers.ts";

const REPO = "test-org/demo";

// maxPerPage 2 caps every list response at two items, so the five changed
// files of the PR span three pages and `gh api --paginate` in owners.sh
// has to follow the Link headers to see them all.
const mock = new MockGitHub({ maxPerPage: 2 });

beforeAll(() => mock.listen());
afterAll(() => mock.close());
beforeEach(() => {
  mock.reset();
  mock.seedUser("ci-bot");
  mock.seedRepo(REPO, { defaultBranch: "main" });
  mock.seedPull(REPO, 7, {
    author: "carol",
    files: [
      "moduleA/x.go",
      "moduleA/sub/y.go",
      "moduleB/z.go",
      "README.md",
      "docs/guide.md",
    ],
  });
  mock.seedContent(
    REPO,
    "OWNERS",
    "approvers:\n  - root-approver\nreviewers:\n  - rev1\n",
  );
  mock.seedContent(REPO, "moduleA/OWNERS", "approvers:\n  - alice\n");
  mock.seedContent(REPO, "moduleB/OWNERS", "approvers:\n  - bob\n");
});

function env(extra: Record<string, string> = {}): Record<string, string> {
  return {
    ...mock.env(),
    GH_REPOSITORY: REPO,
    ISSUE_NUMBER: "7",
    ISSUE_KIND: "pr",
    ...extra,
  };
}

// approveStatus sources owners.sh the same way command.sh does before
// running approve-status.sh.
function approveStatus(args: string, extra: Record<string, string> = {}) {
  return runBash(
    `source owners.sh && load_owners_for_pr && approve-status.sh ${args}`,
    env(extra),
  );
}

function statusComments() {
  return mock
    .listComments(REPO, 7)
    .filter((comment) => comment.body.startsWith("<!-- ci-bot-approve-status"));
}

// stateLines returns the machine-readable "<area> <approver>..." lines
// stored in the hidden block of the status comment.
function stateLines(body: string): string[] {
  const lines = body.split("\n");
  return lines.slice(1, lines.indexOf("-->"));
}

describe("owners.sh", () => {
  it("maps changed files to areas and collects approvers across pages", async () => {
    const result = await runBash(
      'source owners.sh && load_owners_for_pr && echo "${OWNERS_AREA_APPROVERS}"',
      env(),
    );

    expect(result.code).toBe(0);
    // Nested dirs without OWNERS roll up to the nearest owned ancestor,
    // and every area inherits the root approvers.
    expect(result.stdout.trim().split("\n")).toEqual([
      ". root-approver",
      "moduleA alice root-approver",
      "moduleB bob root-approver",
    ]);

    // The five files were served in three pages of two.
    const fileRequests = mock.requests.filter(
      (request) =>
        request.route === "GET /repos/{owner}/{repo}/pulls/{number}/files",
    );
    expect(fileRequests.length).toBe(3);
    expect(fileRequests.map((request) => request.query.page ?? "1")).toEqual([
      "1",
      "2",
      "3",
    ]);

    // OWNERS files are fetched from the default branch.
    const contentRequests = mock.requests.filter(
      (request) =>
        request.route === "GET /repos/{owner}/{repo}/contents/{path}",
    );
    expect(contentRequests.length).toBeGreaterThan(0);
    for (const request of contentRequests) {
      expect(request.query.ref).toBe("main");
    }

    // The owners path is pure REST: every request hit a known route.
    expect(mock.unmatchedRequests).toEqual([]);
  });
});

describe("approve-status.sh", () => {
  it("records a partial approval in a status comment", async () => {
    const result = await approveStatus("approve alice");

    expect(result.code).toBe(0);
    expect(result.stderr).toContain("Area 'moduleA' approved by alice");
    expect(result.stderr).toContain("Areas still requiring approval:");

    const comments = statusComments();
    expect(comments).toHaveLength(1);
    const body = comments[0]!.body;
    expect(stateLines(body)).toEqual([
      ".",
      "moduleA alice",
      "moduleB",
    ]);
    expect(body).toContain("[APPROVALNOTIFIER] This PR is **NOT APPROVED**");
    expect(body).toContain("blob/main/moduleA/OWNERS");
  });

  it("updates the same comment until every area is approved", async () => {
    await approveStatus("approve alice");
    const result = await approveStatus("approve root-approver");

    expect(result.code).toBe(0);
    expect(result.stderr).toContain("All areas approved.");

    // The second run patches the first comment instead of adding one.
    const comments = statusComments();
    expect(comments).toHaveLength(1);
    const body = comments[0]!.body;
    expect(stateLines(body)).toEqual([
      ". root-approver",
      "moduleA alice root-approver",
      "moduleB root-approver",
    ]);
    expect(body).toContain("[APPROVALNOTIFIER] This PR is **APPROVED**");
  });

  it("pre-approves the areas owned by the PR author on sync", async () => {
    const result = await approveStatus("sync", { AUTHOR: "alice" });

    expect(result.code).toBe(0);
    expect(result.stderr).toContain(
      "Area 'moduleA' approved by default: PR author alice is an approver",
    );
    expect(stateLines(statusComments()[0]!.body)).toEqual([
      ".",
      "moduleA alice",
      "moduleB",
    ]);
  });

  it("removes every approval of a user on unapprove", async () => {
    await approveStatus("approve alice");
    await approveStatus("approve root-approver");
    const result = await approveStatus("unapprove root-approver");

    expect(result.code).toBe(0);
    const body = statusComments()[0]!.body;
    expect(stateLines(body)).toEqual([
      ".",
      "moduleA alice",
      "moduleB",
    ]);
    expect(body).toContain("[APPROVALNOTIFIER] This PR is **NOT APPROVED**");
  });

  it("rejects approvals from users who own none of the changed areas", async () => {
    const result = await approveStatus("approve mallory");

    expect(result.code).toBe(1);
    expect(result.stdout).toContain(
      "[FAIL] You are not an approver of any changed area.",
    );
    expect(statusComments()).toHaveLength(0);
  });

  it("drops stale areas on sync while keeping sticky approvals", async () => {
    await approveStatus("approve alice");

    // A new push changes the PR: moduleA is no longer touched.
    mock.seedPull(REPO, 7, {
      author: "carol",
      files: ["moduleB/z.go"],
    });
    mock.clearRequests();

    const result = await approveStatus("sync");

    expect(result.code).toBe(0);
    expect(stateLines(statusComments()[0]!.body)).toEqual(["moduleB"]);
  });
});
