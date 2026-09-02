import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";

import { MockGitHub } from "../mock-github/index.ts";
import { runScript } from "./helpers.ts";

const mock = new MockGitHub();

beforeAll(() => mock.listen());
afterAll(() => mock.close());
beforeEach(() => mock.reset());

describe("bot-login.sh", () => {
  it("prints the login of the user behind the token", async () => {
    mock.seedUser("ci-bot");

    const result = await runScript("bot-login.sh", [], mock.env());

    expect(result.code).toBe(0);
    expect(result.stdout.trim()).toBe("ci-bot");
    expect(
      mock.requests.filter((request) => request.route === "GET /user"),
    ).toHaveLength(1);
    expect(mock.unmatchedRequests).toHaveLength(0);
  });

  it("falls back to github-actions[bot] for installation tokens", async () => {
    // No seeded user: GET /user answers 403 like it does for the Actions
    // installation token, and the script must fall back.
    const result = await runScript("bot-login.sh", [], mock.env());

    expect(result.code).toBe(0);
    expect(result.stdout.trim()).toBe("github-actions[bot]");
  });
});
