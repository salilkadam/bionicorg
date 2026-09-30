import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { defineConfig } from "@playwright/test";

const PORT = Number(process.env.BIONIC_ISSUE_PERF_PORT ?? 3201);
const EXTERNAL_URL = process.env.BIONIC_ISSUE_PERF_BASE_URL;
if (EXTERNAL_URL) {
  const target = new URL(EXTERNAL_URL);
  if (
    !["http:", "https:"].includes(target.protocol) ||
    !["localhost", "127.0.0.1", "[::1]"].includes(target.hostname) ||
    target.username || target.password || target.search || target.hash || target.pathname !== "/"
  ) {
    throw new Error("BIONIC_ISSUE_PERF_BASE_URL must be a loopback origin for a disposable local instance; these tests create fixtures.");
  }
}
const BASE_URL = EXTERNAL_URL ?? `http://127.0.0.1:${PORT}`;
const BIONIC_HOME = fs.mkdtempSync(path.join(os.tmpdir(), "bionic-issue-perf-home-"));
const BIONIC_INSTANCE_ID = "playwright-issue-perf";
const BIONIC_CONFIG = path.join(BIONIC_HOME, "instances", BIONIC_INSTANCE_ID, "config.json");

process.env.BIONIC_HOME = BIONIC_HOME;
process.env.BIONIC_CONFIG = BIONIC_CONFIG;

export default defineConfig({
  testDir: ".",
  testMatch: "*.spec.ts",
  timeout: 30 * 60_000,
  workers: 1,
  fullyParallel: false,
  use: {
    baseURL: BASE_URL,
    browserName: "chromium",
    headless: true,
  },
  webServer: EXTERNAL_URL ? undefined : {
    command: "pnpm bionicai onboard --yes --run",
    url: `${BASE_URL}/api/health`,
    reuseExistingServer: false,
    timeout: 120_000,
    stdout: "pipe",
    stderr: "pipe",
    env: {
      ...process.env,
      NODE_ENV: "development",
      PORT: String(PORT),
      BIONIC_OPEN_ON_LISTEN: "false",
      BIONIC_HOME,
      BIONIC_INSTANCE_ID,
      BIONIC_CONFIG,
      BIONIC_AGENT_JWT_SECRET: "playwright-issue-perf-agent-jwt-secret",
      BIONIC_TOOL_ACTION_SIGNING_SECRET: "playwright-issue-perf-tool-action-signing-secret",
      BIONIC_BIND: "loopback",
      BIONIC_DEPLOYMENT_MODE: "local_trusted",
      BIONIC_DEPLOYMENT_EXPOSURE: "private",
    },
  },
  outputDir: "../../../test-results/issue-detail-perf/playwright",
  reporter: [["list"]],
});
