// Helpers to run the real bin/ scripts as child processes, the same way
// entrypoint.sh runs them in production: by name, with bin/ on PATH.
//
// Scripts must be spawned asynchronously: the mock server runs on this
// process's event loop, so a synchronous spawn would deadlock the test
// against its own server.

import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "..",
);
export const binDir = path.join(repoRoot, "bin");

export interface RunResult {
  code: number | null;
  stdout: string;
  stderr: string;
}

let homeDir: Promise<string> | null = null;

// tempHome is an isolated HOME shared by every child process, keeping gh
// and git from touching the real user profile.
function tempHome(): Promise<string> {
  homeDir ??= fs.mkdtemp(path.join(os.tmpdir(), "gh-ci-bot-e2e-home-"));
  return homeDir;
}

async function run(
  command: string,
  args: string[],
  env: Record<string, string>,
): Promise<RunResult> {
  const home = await tempHome();
  const child = spawn(command, args, {
    cwd: home,
    env: {
      PATH: `${binDir}:${process.env.PATH ?? ""}`,
      HOME: home,
      ...env,
    },
    stdio: ["ignore", "pipe", "pipe"],
    timeout: 30_000,
  });

  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (chunk: Buffer) => {
    stdout += chunk.toString("utf8");
  });
  child.stderr.on("data", (chunk: Buffer) => {
    stderr += chunk.toString("utf8");
  });

  return new Promise((resolve, reject) => {
    child.on("error", reject);
    child.on("close", (code) => resolve({ code, stdout, stderr }));
  });
}

// runScript runs a bin/ script by name, e.g. runScript("bot-login.sh").
export function runScript(
  script: string,
  args: string[] = [],
  env: Record<string, string> = {},
): Promise<RunResult> {
  return run(path.join(binDir, script), args, env);
}

// runBash runs a shell snippet with bin/ on PATH, for scripts that are
// sourced rather than executed (e.g. `source owners.sh`).
export function runBash(
  snippet: string,
  env: Record<string, string> = {},
): Promise<RunResult> {
  return run("bash", ["-c", snippet], env);
}
