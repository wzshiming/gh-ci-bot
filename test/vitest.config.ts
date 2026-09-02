import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["e2e/**/*.test.ts"],
    // Every spec file binds its own mock server on the fixed address
    // 127.0.0.1:80 (the only port gh reaches without TLS), so spec files
    // cannot run in parallel.
    fileParallelism: false,
    testTimeout: 60_000,
    hookTimeout: 60_000,
  },
});
