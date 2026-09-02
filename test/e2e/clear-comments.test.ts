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
  mock.seedIssue(REPO, 3);
});

const env = () => ({
  ...mock.env(),
  GH_REPOSITORY: REPO,
  ISSUE_NUMBER: "3",
});

describe("clear-comments.sh", () => {
  it("deletes only the bot's own comments", async () => {
    mock.seedComment(REPO, 3, "old bot reply", { user: "ci-bot" });
    mock.seedComment(REPO, 3, "a human comment", { user: "alice" });
    mock.seedComment(REPO, 3, "another bot reply", { user: "ci-bot" });

    const result = await runScript("clear-comments.sh", [], env());

    expect(result.code).toBe(0);
    expect(
      mock.listComments(REPO, 3).map((comment) => comment.body),
    ).toEqual(["a human comment"]);
    expect(
      mock.requests.filter((request) => request.method === "DELETE"),
    ).toHaveLength(2);
  });

  it("deletes nothing when the bot has no comments", async () => {
    mock.seedComment(REPO, 3, "a human comment", { user: "alice" });

    const result = await runScript("clear-comments.sh", [], env());

    expect(result.code).toBe(0);
    expect(mock.listComments(REPO, 3)).toHaveLength(1);
    expect(
      mock.requests.filter((request) => request.method === "DELETE"),
    ).toHaveLength(0);
  });
});
