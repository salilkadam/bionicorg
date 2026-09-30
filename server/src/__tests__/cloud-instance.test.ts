import { describe, expect, it } from "vitest";
import {
  getCloudStackContext,
  isCloudManagedInstance,
  type CloudInstanceEnv,
} from "../services/cloud-instance.js";

describe("isCloudManagedInstance", () => {
  it("unifies both prior signals without weakening either restrictive floor", () => {
    const cases: CloudInstanceEnv[] = [
      {},
      { BIONIC_CLOUD_TENANT_SERVER_TOKEN: "tenant-token" },
      { BIONIC_MANAGED_CONFIG: "" },
      {
        BIONIC_CLOUD_TENANT_SERVER_TOKEN: "tenant-token",
        BIONIC_MANAGED_CONFIG: "managed-document",
      },
    ];

    for (const env of cases) {
      const priorTokenFloor = Boolean(env.BIONIC_CLOUD_TENANT_SERVER_TOKEN?.trim());
      const priorManagedConfigFloor = env.BIONIC_MANAGED_CONFIG !== undefined;
      const canonicalFloor = isCloudManagedInstance(env);

      expect(canonicalFloor).toBe(priorTokenFloor || priorManagedConfigFloor);
      expect(canonicalFloor || !priorTokenFloor).toBe(true);
      expect(canonicalFloor || !priorManagedConfigFloor).toBe(true);
    }
  });

  it("does not treat a blank tenant token alone as a managed signal", () => {
    expect(isCloudManagedInstance({ BIONIC_CLOUD_TENANT_SERVER_TOKEN: "   " })).toBe(false);
  });
});

describe("getCloudStackContext", () => {
  it("returns null outside Bionic Cloud even when stray stack metadata exists", () => {
    expect(getCloudStackContext({ BIONIC_STACK_SLUG: "stray-stack" })).toBeNull();
  });

  it("returns normalized provisioner metadata for cloud instances", () => {
    expect(getCloudStackContext({
      BIONIC_CLOUD_TENANT_SERVER_TOKEN: "tenant-token",
      BIONIC_CLOUD_STACK_ID: " stack-1 ",
      BIONIC_STACK_SLUG: " acme ",
      BIONIC_CLOUD_ACCOUNT_GROUP_ID: " account-group-1 ",
      BIONIC_PRIMARY_HOST: " acme.bionic.app ",
      BIONIC_CLOUD_API_ORIGIN: " https://app.bionic.app ",
    })).toEqual({
      stackId: "stack-1",
      stackSlug: "acme",
      accountGroupId: "account-group-1",
      primaryHost: "acme.bionic.app",
      cloudOrigin: "https://app.bionic.app",
    });
  });

  it("represents missing managed metadata explicitly without failing health checks", () => {
    expect(getCloudStackContext({ BIONIC_MANAGED_CONFIG: "managed-document" })).toEqual({
      stackId: null,
      stackSlug: null,
      accountGroupId: null,
      primaryHost: null,
      cloudOrigin: null,
    });
  });
});
