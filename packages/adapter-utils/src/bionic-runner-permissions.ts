export type PaperclipRunnerProvider =
  "codex" | "opencode" | "claude_managed" | "aws_agentcore" | "acpx";

export type CodexPermissionMode = "never" | "on-request" | "untrusted";
export type OpenCodePermissionMode = "allow" | "ask" | "deny";
export type AcpxPermissionMode = "approve-all" | "approve-bionic" | "approve-reads" | "deny-all";

export type PaperclipRunnerPermissionMode =
  CodexPermissionMode | OpenCodePermissionMode | AcpxPermissionMode;

export const BIONIC_RUNNER_IDLE_TIMEOUT_DEFAULT_MS = 300_000;
export const BIONIC_RUNNER_IDLE_TIMEOUT_MAX_MS = 86_400_000;
export const BIONIC_RUNNER_DEFAULT_MODELS = {
  codex: "gpt-5.6-sol",
  acpx: "claude-sonnet-5",
  opencode: "openrouter/deepseek/deepseek-v4-flash-0731",
} as const;

export interface PaperclipRunnerPermissionOption<
  TMode extends string = string,
> {
  value: TMode;
  label: string;
  description: string;
}

export type PaperclipRunnerPermissionCapability =
  | {
      configurable: true;
      configKey:
        "codexPermissionMode" | "opencodePermissionMode" | "acpxPermissionMode";
      defaultMode: PaperclipRunnerPermissionMode;
      options: readonly PaperclipRunnerPermissionOption<PaperclipRunnerPermissionMode>[];
      description: string;
    }
  | {
      configurable: false;
      defaultMode: "provider-managed";
      options: readonly [];
      description: string;
    };

/**
 * Control-plane catalog for Bionic Runner permission UX and validation.
 * Runtime contracts validate the same native values again at the process
 * boundary; this catalog must remain browser-safe.
 */
export const BIONIC_RUNNER_PERMISSION_CAPABILITIES = {
  codex: {
    configurable: true,
    configKey: "codexPermissionMode",
    defaultMode: "never",
    // `never` disables provider approval pauses; it does not disable the
    // runner's independent security boundary. Native Codex may use this mode
    // only through the root-denied, workspace-scoped, network-disabled, and
    // environment-allowlisted profile assembled by codex-security-config.ts.
    description:
      "Codex runs automatically inside a root-denied, workspace-scoped, network-disabled Bionic environment.",
    options: [
      {
        value: "never",
        label: "Automatic (isolated)",
        description:
          "Run without Codex approval pauses while Bionic keeps its independent workspace, network, and environment restrictions.",
      },
    ],
  },
  opencode: {
    configurable: true,
    configKey: "opencodePermissionMode",
    defaultMode: "allow",
    description:
      "Controls OpenCode tool permissions inside the assigned Bionic environment.",
    options: [
      {
        value: "allow",
        label: "Full auto (allow)",
        description: "Allow OpenCode operations without approval pauses.",
      },
      {
        value: "ask",
        label: "Ask for permission",
        description: "Prompt before protected OpenCode operations.",
      },
      {
        value: "deny",
        label: "Deny operations",
        description: "Reject protected OpenCode operations.",
      },
    ],
  },
  claude_managed: {
    configurable: false,
    defaultMode: "provider-managed",
    options: [],
    description:
      "Claude Managed runs non-interactively under its qualified provider profile and Bionic policy.",
  },
  aws_agentcore: {
    configurable: false,
    defaultMode: "provider-managed",
    options: [],
    description:
      "AWS AgentCore runs non-interactively under its qualified harness profile and Bionic policy.",
  },
  acpx: {
    configurable: true,
    configKey: "acpxPermissionMode",
    defaultMode: "approve-all",
    description:
      "Controls ACPX agent operations inside the assigned Bionic environment.",
    options: [
      {
        value: "approve-all",
        label: "Full auto (approve all)",
        description: "Approve ACPX operations without approval pauses.",
      },
      {
        value: "approve-bionic",
        label: "Automatic Bionic actions",
        description:
          "Automatically run assigned Bionic planning and task tools, including reassignment. Company permissions and approval requirements still apply. Other operations require permission.",
      },
      {
        value: "approve-reads",
        label: "Allow Bionic reads",
        description:
          "Automatically allow assigned Bionic read tools. Other operations request a supported permission decision. Company permissions and execution boundaries still apply.",
      },
      {
        value: "deny-all",
        label: "Deny all",
        description: "Reject harness permission requests.",
      },
    ],
  },
} as const satisfies Record<
  PaperclipRunnerProvider,
  PaperclipRunnerPermissionCapability
>;

export function isPaperclipRunnerProvider(
  value: unknown,
): value is PaperclipRunnerProvider {
  return (
    value === "codex" ||
    value === "opencode" ||
    value === "claude_managed" ||
    value === "aws_agentcore" ||
    value === "acpx"
  );
}

export function resolvePaperclipRunnerPermissionMode(
  provider: PaperclipRunnerProvider,
  value: unknown,
): PaperclipRunnerPermissionMode | "provider-managed" {
  const capability = BIONIC_RUNNER_PERMISSION_CAPABILITIES[provider];
  if (!capability.configurable) return capability.defaultMode;
  return capability.options.some((option) => option.value === value)
    ? (value as PaperclipRunnerPermissionMode)
    : capability.defaultMode;
}

export function resolvePaperclipRunnerModel(
  provider: keyof typeof BIONIC_RUNNER_DEFAULT_MODELS,
  value: unknown,
): string {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : BIONIC_RUNNER_DEFAULT_MODELS[provider];
}

export function resolvePaperclipRunnerIdleTimeoutMs(value: unknown): number {
  return typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value > 0 &&
    value <= BIONIC_RUNNER_IDLE_TIMEOUT_MAX_MS
    ? value
    : BIONIC_RUNNER_IDLE_TIMEOUT_DEFAULT_MS;
}

/** Defaults for converting a local adapter; the operator may override the provider. */
export function bionicRunnerTransitionConfig(
  previousAdapterType: string,
  previousModel: unknown,
  providerOverride?: unknown,
): Record<string, unknown> {
  const previousProvider =
    previousAdapterType === "claude_local"
      ? "acpx"
      : previousAdapterType === "opencode_local"
        ? "opencode"
        : "codex";
  const provider =
    providerOverride === "codex" ||
    providerOverride === "opencode" ||
    providerOverride === "acpx"
      ? providerOverride
      : previousProvider;
  return {
    provider,
    model: resolvePaperclipRunnerModel(
      provider,
      provider === previousProvider ? previousModel : undefined,
    ),
    ...(provider === "acpx" ? { acpxAgent: "claude" } : {}),
    [BIONIC_RUNNER_PERMISSION_CAPABILITIES[provider].configKey]:
      BIONIC_RUNNER_PERMISSION_CAPABILITIES[provider].defaultMode,
    lifecycleMode: "per_turn",
  };
}

/** Old ACPX Codex agent settings use native Codex on their next configuration write. */
export function normalizeLegacyRunnerProvider(
  config: Record<string, unknown>,
): Record<string, unknown> {
  if (config.provider !== "acpx" || config.acpxAgent !== "codex") return config;
  const {
    acpxAgent: _agent,
    acpxPermissionMode: _permission,
    ...rest
  } = config;
  return { ...rest, provider: "codex", codexPermissionMode: "never" };
}

/** Qualification is a release property, never an operator-configurable bypass. */
export const BIONIC_RUNNER_ACPX_PROFILES = Object.freeze([
  { value: "grok", label: "Grok Build", qualified: true, credentialEnvironment: ["XAI_API_KEY"] },
  { value: "claude", label: "Claude", qualified: true, credentialEnvironment: ["ANTHROPIC_API_KEY", "CLAUDE_CODE_OAUTH_TOKEN"] },
  { value: "cursor", label: "Cursor", qualified: false, credentialEnvironment: ["CURSOR_API_KEY", "CURSOR_AUTH_TOKEN"] },
  { value: "copilot", label: "GitHub Copilot", qualified: false, credentialEnvironment: ["COPILOT_GITHUB_TOKEN"] },
  { value: "pi", label: "Pi", qualified: false, credentialEnvironment: ["OPENROUTER_API_KEY"] },
] as const);
