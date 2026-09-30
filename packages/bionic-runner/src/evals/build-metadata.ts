import { createHash } from "node:crypto";

import { BIONIC_RUNNER_COMPATIBILITY } from "../compatibility.js";
import {
  PRP_PROTOCOL_MIN_VERSION,
  PRP_PROTOCOL_NAME,
  PRP_PROTOCOL_VERSION,
} from "../protocol/replay-contract.js";
import { canonicalCapabilitySemanticCatalog } from "../semantic-tools/catalog.js";

export const BIONIC_RUNNER_BUILD_METADATA_SCHEMA =
  "bionic-runner/build-metadata/v1" as const;
export const BIONIC_RUNNER_NATIVE_EXECUTION_SCHEMA =
  "bionic-runner/native-execution/v1" as const;
export const BIONIC_RUNNER_EVAL_INTEGRATION_SCHEMA =
  "bionic-runner/evals-integration/v1" as const;
export const BIONIC_RUNNERD_BUILD_METADATA_SCHEMA =
  "bionic-runner/runnerd-build-metadata/v1" as const;

export const BIONIC_RUNNER_SEMANTIC_CATALOG_SHA256 =
  `sha256:${createHash("sha256")
    .update(canonicalCapabilitySemanticCatalog())
    .digest("hex")}` as const;

/**
 * App-owned release metadata that Evals pins beside every native attempt.
 * Contract versions are independent from package semver so consumers can give
 * a precise mismatch instead of guessing from a package version.
 */
export const BIONIC_RUNNER_BUILD_METADATA = Object.freeze({
  schema: BIONIC_RUNNER_BUILD_METADATA_SCHEMA,
  package: Object.freeze({
    name: BIONIC_RUNNER_COMPATIBILITY.packageName,
    version: BIONIC_RUNNER_COMPATIBILITY.packageVersion,
  }),
  contracts: Object.freeze({
    evalIntegration: BIONIC_RUNNER_COMPATIBILITY.components.evalIntegration,
    nativeExecution: BIONIC_RUNNER_COMPATIBILITY.components.nativeExecution,
    runnerdArtifact: BIONIC_RUNNER_COMPATIBILITY.components.runnerdBinary,
    prp: PRP_PROTOCOL_VERSION,
    semanticCatalog: BIONIC_RUNNER_COMPATIBILITY.components.catalog,
    harnessDriver: BIONIC_RUNNER_COMPATIBILITY.components.harnessDriver,
    controlPlaneAdapter: BIONIC_RUNNER_COMPATIBILITY.components.controlPlaneAdapter,
    testkit: BIONIC_RUNNER_COMPATIBILITY.components.testkit,
  }),
  prp: Object.freeze({
    name: PRP_PROTOCOL_NAME,
    minimumVersion: PRP_PROTOCOL_MIN_VERSION,
    maximumVersion: PRP_PROTOCOL_VERSION,
  }),
  semanticCatalog: Object.freeze({
    version: BIONIC_RUNNER_COMPATIBILITY.components.catalog,
    sha256: BIONIC_RUNNER_SEMANTIC_CATALOG_SHA256,
  }),
  runnerd: Object.freeze({
    binaryName: "bionic-runnerd" as const,
    metadataSchema: BIONIC_RUNNERD_BUILD_METADATA_SCHEMA,
    digestAlgorithm: "sha256" as const,
  }),
});

export type PaperclipRunnerBuildMetadata = typeof BIONIC_RUNNER_BUILD_METADATA;
