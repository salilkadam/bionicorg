import type { DeploymentMode, DeploymentExposure } from "@bionicai/shared";

/** Same server-host boundary as local stdio runtimes. */
export function supportsLocalAiLogin(options: {
  deploymentMode?: DeploymentMode;
  deploymentExposure?: DeploymentExposure;
  trustedLocalStdioRuntimeHost?: string | null;
}) {
  return options.deploymentMode !== "authenticated" || options.deploymentExposure !== "public" || Boolean(
    options.trustedLocalStdioRuntimeHost ?? process.env.BIONIC_TRUSTED_MCP_RUNTIME_HOST ?? process.env.BIONIC_TOOL_RUNTIME_TRUSTED_HOST,
  );
}
