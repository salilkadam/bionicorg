import path from "node:path";
import { chatNeedsApiTools, isManagedHiringCase } from "./chat-cases.js";
import { CREDENTIAL_NAMES } from "./types.js";
import type { MatrixExecution } from "./types.js";

const DATABASE_KEYS = ["DATABASE_URL", "DATABASE_MIGRATION_URL"] as const;
const AMBIENT_BIONIC_CREDENTIAL_KEYS = [
  "BIONIC_API_KEY",
  "BIONIC_AGENT_API_KEY",
  "BIONIC_TASK_BRIDGE_TOKEN",
  "BIONIC_SETUP_TOKEN",
  "BIONIC_SECRETS_MASTER_KEY",
  "BIONIC_SECRETS_MASTER_KEY_FILE",
] as const;
const GENERATED_SERVER_SECRET_KEYS = [
  "BIONIC_AGENT_JWT_SECRET",
  "BIONIC_DECISION_SIGNING_SECRET",
  "BIONIC_TOOL_ACTION_SIGNING_SECRET",
  "BETTER_AUTH_SECRET",
] as const;
const AMBIENT_EXTERNAL_STATE_KEYS = [
  "BIONIC_STORAGE_S3_BUCKET",
  "BIONIC_STORAGE_S3_REGION",
  "BIONIC_STORAGE_S3_ENDPOINT",
  "BIONIC_STORAGE_S3_PREFIX",
  "BIONIC_STORAGE_S3_FORCE_PATH_STYLE",
] as const;
const PROVIDER_SECRET_KEY = /^(?:OPENAI|ANTHROPIC|OPENROUTER|DAYTONA|XAI|GROK|CURSOR|COPILOT|GITHUB|GH)(?:_|$)/;

export function runnerE2EServerControlPaths(temporaryRoot: string) {
  const controlDirectory = path.join(temporaryRoot, "control");
  return {
    controlDirectory,
    restartRequestPath: path.join(
      controlDirectory,
      "server-restart.request.json",
    ),
    restartAcknowledgementPath: path.join(
      controlDirectory,
      "server-restart.ack.json",
    ),
  };
}

/**
 * Native cells use the debug binary produced once by build:runner-binaries.
 * Preserve an explicit override for release builds and developer workflows.
 */
export function resolvePaperclipRunnerBinaryForHarness(
  executions: readonly MatrixExecution[],
  repositoryRoot: string,
  configuredPath = process.env.BIONIC_RUNNER_BINARY,
  platform: NodeJS.Platform = process.platform,
): string | undefined {
  if (configuredPath?.trim()) return configuredPath;
  if (
    !executions.some((execution) => execution.profile.generation === "native")
  ) {
    return undefined;
  }

  return path.join(
    repositoryRoot,
    "packages",
    "bionic-runner",
    "runner",
    "target",
    "debug",
    platform === "win32" ? "bionic-runnerd.exe" : "bionic-runnerd",
  );
}

/**
 * Remote native cells stage the same controller-owned binary whose digest is
 * authorized by the PRP control plane. Local cells launch it directly.
 */
export function resolvePaperclipRemoteRunnerBinaryForHarness(
  executions: readonly MatrixExecution[],
  runnerBinary: string | undefined,
  configuredPath = process.env.BIONIC_RUNNER_REMOTE_BINARY_PATH,
  platform: NodeJS.Platform = process.platform,
): string | undefined {
  if (configuredPath?.trim()) return configuredPath;
  if (!runnerBinary) return undefined;
  // Daytona runs Linux. A default debug binary built by a macOS developer is
  // Mach-O and cannot be staged into that sandbox. Leave the remote override
  // unset so the pinned Daytona image's verified runnerd is discovered instead.
  if (platform !== "linux") return undefined;
  return executions.some(
    (execution) =>
      execution.profile.generation === "native" &&
      execution.environment.expectedExecutionTarget.kind === "remote",
  )
    ? runnerBinary
    : undefined;
}

/**
 * Keep fixture-only provider switches scoped to the one isolated harness that
 * needs them. In particular, the pinned legacy OpenCode model is routed by the
 * paid gateway and may not appear in OpenCode's public model catalog.
 */
export function buildRunnerE2EProcessEnvironment(
  source: NodeJS.ProcessEnv,
  executions: readonly MatrixExecution[],
): NodeJS.ProcessEnv {
  const result = { ...source };
  // Announcements are unrelated to the scenarios and obscure screenshot evidence.
  result.BIONIC_ANNOUNCEMENTS_ENABLED = "false";
  delete result.OPENCODE_ALLOW_ALL_MODELS;
  // Discard ambient admission. Only explicit candidate cells authorize the
  // exact model in their isolated server; credentials still use company secrets.
  delete result.BIONIC_RUNNER_ACPX_QUALIFICATION;
  const candidates = new Map<string, string>();
  for (const execution of executions) {
    const agent = execution.profile.qualificationCandidate;
    if (!agent) continue;
    if (execution.suite.id !== "extended-harnesses" || !execution.suite.manualOnly) {
      throw new Error("Candidate qualification requires the explicit extended-harnesses suite");
    }
    const prior = candidates.get(agent);
    if (prior !== undefined && prior !== execution.profile.model) throw new Error("Conflicting candidate models");
    candidates.set(agent, execution.profile.model);
  }
  if (candidates.size > 0) {
    result.BIONIC_RUNNER_ACPX_QUALIFICATION = JSON.stringify(
      [...candidates].map(([agent, model]) => ({ agent, model })),
    );
  }
  // These stories explicitly require the native API surface. Other suites
  // retain the server default or any supplied operator restriction.
  if (executions.some((e) => isManagedHiringCase(e.suite.id, e.task.id) || chatNeedsApiTools(e.suite.id, e.task.id))) {
    result.BIONIC_RUNNER_API_TOOLS_ENABLED = "true";
  }
  if (
    executions.length > 0 &&
    executions.every(
      (execution) =>
        execution.profile.generation === "legacy" &&
        execution.profile.provider === "opencode",
    )
  ) {
    result.OPENCODE_ALLOW_ALL_MODELS = "true";
  }
  return result;
}

/**
 * Build the environment inherited by the Bionic server. Paid credentials
 * deliberately stay in the launcher/Playwright process and cross the server
 * boundary through encrypted company secrets. Explicit subscription fixtures
 * stage their login in the disposable company's private credential home.
 */
export function buildPaperclipServerEnvironment(
  source: NodeJS.ProcessEnv,
  overrides: NodeJS.ProcessEnv = {},
): NodeJS.ProcessEnv {
  const result = { ...source };
  for (const key of Object.keys(result)) {
    if (PROVIDER_SECRET_KEY.test(key)) delete result[key];
  }
  for (const key of [
    ...CREDENTIAL_NAMES,
    ...DATABASE_KEYS,
    ...AMBIENT_BIONIC_CREDENTIAL_KEYS,
    ...AMBIENT_EXTERNAL_STATE_KEYS,
  ]) {
    delete result[key];
  }
  for (const key of GENERATED_SERVER_SECRET_KEYS) delete result[key];
  Object.assign(result, overrides);
  return result;
}

export function assertIsolatedServerEnvironment(
  env: NodeJS.ProcessEnv,
  expected: {
    temporaryRoot: string;
    bionicHome: string;
    configPath: string;
  },
) {
  const home = env.BIONIC_HOME;
  const config = env.BIONIC_CONFIG;
  if (home !== expected.bionicHome || config !== expected.configPath) {
    throw new Error(
      "Bionic server environment does not use the allocated home/config paths",
    );
  }
  if (
    !home.startsWith(`${expected.temporaryRoot}/`) ||
    !config.startsWith(`${expected.temporaryRoot}/`)
  ) {
    throw new Error(
      "Bionic server paths escape the isolated temporary root",
    );
  }
  if (env.XDG_CACHE_HOME !== path.join(expected.temporaryRoot, "xdg-cache")) {
    throw new Error(
      "Bionic server cache does not use the allocated temporary root",
    );
  }
  for (const key of [
    ...CREDENTIAL_NAMES,
    ...DATABASE_KEYS,
    ...AMBIENT_BIONIC_CREDENTIAL_KEYS,
    ...AMBIENT_EXTERNAL_STATE_KEYS,
  ]) {
    if (env[key])
      throw new Error(
        `Bionic server environment unexpectedly contains ${key}`,
      );
  }
  for (const key of GENERATED_SERVER_SECRET_KEYS) {
    if (!env[key])
      throw new Error(`Bionic server environment is missing ${key}`);
  }
}
