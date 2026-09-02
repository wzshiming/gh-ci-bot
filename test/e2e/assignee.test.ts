import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

import { MockGitHub } from "../mock-github/index.ts";
import { runScript } from "./helpers.ts";

const REPO = "test-org/demo";
const mock = new MockGitHub();

beforeAll(() => mock.listen());
afterAll(() => mock.close());
beforeEach(() => {
  mock.reset();
  mock.seedUser("ci-bot");
  mock.seedRepo(REPO);
});

function env(extra: Record<string, string> = {}): Record<string, string> {
  return {
    ...mock.env(),
    GH_REPOSITORY: REPO,
    ISSUE_NUMBER: "12",
    ...extra,
  };
}

function assignees(): string[] {
  return mock.getIssue(REPO, 12).assignees.map((user) => user.login);
}

describe("add-assignee.sh", () => {
  it("assigns a user through the REST API", async () => {
    mock.seedIssue(REPO, 12);

    const result = await runScript("add-assignee.sh", ["@alice"], env());

    expect(result.code).toBe(0);
    expect(assignees()).toEqual(["alice"]);
    const posts = mock.requests.filter(
      (request) =>
        request.route === "POST /repos/{owner}/{repo}/issues/{number}/assignees",
    );
    expect(posts).toHaveLength(1);
    expect(posts[0]?.path).toBe("/repos/test-org/demo/issues/12/assignees");
  });

  it("assigns several comma-separated users one by one", async () => {
    mock.seedIssue(REPO, 12);

    // command.sh passes arguments through, e.g. `/assign @alice @Bob-Builder`.
    // Logins keep their case: assigning uppercase logins through
    // `gh issue edit` is what broke in wzshiming/gh-ci-bot#26.
    const result = await runScript(
      "add-assignee.sh",
      ["@alice", "@Bob-Builder"],
      env(),
    );

    expect(result.code).toBe(0);
    expect(assignees()).toEqual(["alice", "Bob-Builder"]);
    expect(
      mock.requests
        .filter((request) => request.method === "POST")
        .map((request) => request.json),
    ).toEqual([{ assignees: ["alice"] }, { assignees: ["Bob-Builder"] }]);
  });

  it("fails without a username", async () => {
    mock.seedIssue(REPO, 12);

    const result = await runScript("add-assignee.sh", [], env());

    expect(result.code).toBe(1);
    expect(result.stdout).toContain("[FAIL] Missing required argument");
    expect(mock.requests).toHaveLength(0);
  });
});

describe("remove-assignee.sh", () => {
  it("removes only the given assignee", async () => {
    mock.seedIssue(REPO, 12, { assignees: ["alice", "bob"] });

    const result = await runScript("remove-assignee.sh", ["@alice"], env());

    expect(result.code).toBe(0);
    expect(assignees()).toEqual(["bob"]);
    const deletes = mock.requests.filter(
      (request) => request.method === "DELETE",
    );
    expect(deletes).toHaveLength(1);
    expect(deletes[0]?.json).toEqual({ assignees: ["alice"] });
  });

  it("fails without a username", async () => {
    mock.seedIssue(REPO, 12, { assignees: ["alice"] });

    const result = await runScript("remove-assignee.sh", [], env());

    expect(result.code).toBe(1);
    expect(result.stdout).toContain("[FAIL] Missing required argument");
    expect(assignees()).toEqual(["alice"]);
  });
});
