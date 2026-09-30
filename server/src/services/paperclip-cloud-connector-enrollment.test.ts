import { mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  completePaperclipCloudConnectorEnrollment,
  loadPaperclipCloudConnectorIdentity,
  bionicCloudConnectorEnrollmentStatus,
  bionicCloudConnectorIdentityPath,
  startPaperclipCloudConnectorEnrollment,
} from "./bionic-cloud-connector-enrollment.js";
import { bionicCloudConnectorConfigFromEnv } from "./bionic-cloud-connector.js";
import { reconcilePaperclipCloudConnectorEnrollmentStatus } from "./bionic-cloud-connector-status.js";

describe("Bionic Cloud self-host enrollment", () => {
  let root = "";
  let previousHome: string | undefined;
  let previousInstance: string | undefined;

  beforeEach(() => {
    root = mkdtempSync(path.join(os.tmpdir(), "bionic-cloud-connector-"));
    previousHome = process.env.BIONIC_HOME;
    previousInstance = process.env.BIONIC_INSTANCE_ID;
    process.env.BIONIC_HOME = root;
    process.env.BIONIC_INSTANCE_ID = "connector-test";
  });

  afterEach(() => {
    if (previousHome === undefined) delete process.env.BIONIC_HOME;
    else process.env.BIONIC_HOME = previousHome;
    if (previousInstance === undefined) delete process.env.BIONIC_INSTANCE_ID;
    else process.env.BIONIC_INSTANCE_ID = previousInstance;
    rmSync(root, { recursive: true, force: true });
  });

  it("keeps private keys owner-only and activates only the matching one-time callback", async () => {
    const requests: Array<{ url: string; body: Record<string, unknown> }> = [];
    const request = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      const url = String(input);
      const body = JSON.parse(String(init?.body)) as Record<string, unknown>;
      requests.push({ url, body });
      if (url.endsWith("/v1/connector/enrollments")) {
        return Response.json({
          enrollmentId: "enroll-test",
          verificationUrl: "https://my.example.test/connections/enroll?id=enroll-test",
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
        }, { status: 201 });
      }
      const token = String(body.request);
      const claims = JSON.parse(Buffer.from(token.split(".")[1]!, "base64url").toString("utf8")) as Record<string, unknown>;
      expect(claims).toMatchObject({
        iss: loadPaperclipCloudConnectorIdentity()?.instanceId,
        aud: "https://my.example.test/v1/connector/enrollment-claims",
        env: "development",
        op: "enroll",
      });
      expect(typeof claims.ah).toBe("string");
      return Response.json({
        id: loadPaperclipCloudConnectorIdentity()?.instanceId,
        environment: "development",
        origins: ["https://private.example.test"],
      });
    });

    const pending = await startPaperclipCloudConnectorEnrollment({
      origin: "https://private.example.test",
      env: {
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.example.test",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "development",
      },
      request: request as typeof fetch,
    });
    expect(pending.status).toBe("pending");
    expect(pending.verificationUrl).toBe("https://my.example.test/connections/enroll?id=enroll-test");
    expect(statSync(path.dirname(bionicCloudConnectorIdentityPath())).mode & 0o777).toBe(0o700);
    expect(statSync(bionicCloudConnectorIdentityPath()).mode & 0o777).toBe(0o600);
    expect(readFileSync(bionicCloudConnectorIdentityPath(), "utf8")).not.toContain("approval-code");

    await expect(completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-test",
      approvalCode: "approval-code",
      state: "wrong-state",
      request: request as typeof fetch,
    })).rejects.toThrow(/Invalid or expired/);

    const state = loadPaperclipCloudConnectorIdentity()?.pending?.returnState;
    const active = await completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-test",
      approvalCode: "approval-code",
      state: state!,
      request: request as typeof fetch,
    });
    expect(active).toMatchObject({ configured: true, status: "active", origins: ["https://private.example.test"] });
    const config = bionicCloudConnectorConfigFromEnv({});
    expect(config).toMatchObject({ baseUrl: "https://my.example.test", environment: "development" });
    expect(requests).toHaveLength(2);

    const statusRequest = vi.fn(async (input: string | URL | Request) => {
      expect(String(input)).toBe("https://my.example.test/v1/connector/instance-status");
      return Response.json({ active: false, status: "suspended" });
    });
    await expect(reconcilePaperclipCloudConnectorEnrollmentStatus({}, statusRequest as typeof fetch)).resolves.toMatchObject({
      configured: false,
      status: "suspended",
      instanceId: active.instanceId,
    });
  });

  it("rejects non-loopback plain HTTP destinations before creating keys", async () => {
    await expect(startPaperclipCloudConnectorEnrollment({
      origin: "http://private.example.test",
      request: vi.fn() as typeof fetch,
    })).rejects.toThrow(/requires HTTPS/);
    expect(bionicCloudConnectorEnrollmentStatus().status).toBe("not_configured");
  });

  it.each([
    "https://my.example.test/connections/enroll?id=another-enrollment",
    "https://my.example.test/connections/enroll",
    "https://my.example.test/connections/enroll?id=enroll-test&next=%2Faccount",
    "https://my.example.test/connections/enroll?id=enroll-test#fragment",
    "https://user@my.example.test/connections/enroll?id=enroll-test",
  ])("rejects an imprecise broker verification destination: %s", async (verificationUrl) => {
    await expect(startPaperclipCloudConnectorEnrollment({
      origin: "https://private.example.test",
      env: {
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.example.test",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "development",
      },
      request: vi.fn(async () => Response.json({
        enrollmentId: "enroll-test",
        verificationUrl,
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
      }, { status: 201 })) as typeof fetch,
    })).rejects.toThrow(/invalid enrollment destination/);
  });

  it("serializes overlapping starts and reuses one unexpired enrollment", async () => {
    let releaseBroker!: () => void;
    const brokerMayRespond = new Promise<void>((resolve) => {
      releaseBroker = resolve;
    });
    const request = vi.fn(async () => {
      await brokerMayRespond;
      return Response.json({
        enrollmentId: "enroll-shared",
        verificationUrl: "https://my.example.test/connections/enroll?id=enroll-shared",
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
      }, { status: 201 });
    });
    const values = {
      origin: "https://private.example.test",
      companyId: "company-test",
      initiatedBy: "user:admin-test",
      env: {
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.example.test",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "development",
      },
      request: request as typeof fetch,
    };

    const first = startPaperclipCloudConnectorEnrollment(values);
    await vi.waitFor(() => expect(request).toHaveBeenCalledOnce());
    const second = startPaperclipCloudConnectorEnrollment(values);
    releaseBroker();

    const [firstStatus, secondStatus] = await Promise.all([first, second]);
    expect(request).toHaveBeenCalledOnce();
    expect(firstStatus).toMatchObject({ status: "pending", verificationUrl: expect.stringContaining("enroll-shared") });
    expect(secondStatus).toEqual(firstStatus);
    expect(loadPaperclipCloudConnectorIdentity()?.pending).toMatchObject({
      enrollmentId: "enroll-shared",
      companyId: "company-test",
      initiatedBy: "user:admin-test",
    });
    await expect(startPaperclipCloudConnectorEnrollment({
      ...values,
      initiatedBy: "user:another-admin",
    })).rejects.toThrow(/another administrator/);
    await expect(startPaperclipCloudConnectorEnrollment({
      ...values,
      companyId: "another-company",
    })).rejects.toThrow(/another company/);
    expect(request).toHaveBeenCalledOnce();
  });

  it("defaults an enrollment to the environment of the standard Cloud broker", () => {
    expect(bionicCloudConnectorEnrollmentStatus({})).toMatchObject({
      brokerBaseUrl: "https://my.bionic.app",
      environment: "production",
    });
    expect(bionicCloudConnectorEnrollmentStatus({
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
    })).toMatchObject({ environment: "staging" });
  });

  it("rotates a non-active identity instead of mixing enrollment targets", async () => {
    const origin = "https://private.example.test";
    const productionRequest = vi.fn(async () => Response.json({
      enrollmentId: "enroll-production",
      verificationUrl: "https://my.bionic.app/connections/enroll?id=enroll-production",
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
    }, { status: 201 }));
    await startPaperclipCloudConnectorEnrollment({
      origin,
      env: { BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.bionic.app" },
      request: productionRequest as typeof fetch,
    });
    const productionIdentity = loadPaperclipCloudConnectorIdentity()!;

    expect(bionicCloudConnectorEnrollmentStatus({
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
    })).toEqual({
      configured: false,
      status: "unverified",
      brokerBaseUrl: "https://my-staging.bionic.app",
      instanceId: null,
      environment: "staging",
      origins: [],
    });

    const stagingRequest = vi.fn(async (input: string | URL | Request, init?: RequestInit) => {
      expect(String(input)).toBe("https://my-staging.bionic.app/v1/connector/enrollments");
      expect(JSON.parse(String(init?.body))).toMatchObject({ environment: "staging", origin });
      return Response.json({
        enrollmentId: "enroll-staging",
        verificationUrl: "https://my-staging.bionic.app/connections/enroll?id=enroll-staging",
        expiresAt: new Date(Date.now() + 60_000).toISOString(),
      }, { status: 201 });
    });
    const stagingStatus = await startPaperclipCloudConnectorEnrollment({
      origin,
      env: { BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app" },
      request: stagingRequest as typeof fetch,
    });
    const stagingIdentity = loadPaperclipCloudConnectorIdentity()!;

    expect(stagingStatus).toMatchObject({
      status: "pending",
      brokerBaseUrl: "https://my-staging.bionic.app",
      environment: "staging",
      verificationUrl: "https://my-staging.bionic.app/connections/enroll?id=enroll-staging",
    });
    expect(stagingIdentity.instanceId).not.toBe(productionIdentity.instanceId);
    expect(stagingIdentity.signPublicKey).not.toBe(productionIdentity.signPublicKey);
    expect(stagingIdentity.sealPublicKey).not.toBe(productionIdentity.sealPublicKey);
    expect(stagingRequest).toHaveBeenCalledOnce();
  });

  it("fails closed when the configured target changes during callback or after activation", async () => {
    const origin = "https://private.example.test";
    const productionEnv = {
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.bionic.app",
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "production",
    };
    const request = vi.fn(async (input: string | URL | Request) => {
      if (String(input).endsWith("/v1/connector/enrollments")) {
        return Response.json({
          enrollmentId: "enroll-production",
          verificationUrl: "https://my.bionic.app/connections/enroll?id=enroll-production",
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
        }, { status: 201 });
      }
      return Response.json({
        id: loadPaperclipCloudConnectorIdentity()?.instanceId,
        environment: "production",
        origins: [origin],
      });
    });
    await startPaperclipCloudConnectorEnrollment({ origin, env: productionEnv, request: request as typeof fetch });
    const pending = loadPaperclipCloudConnectorIdentity()!;
    const changedTargetRequest = vi.fn();

    await expect(completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-production",
      approvalCode: "approval-code",
      state: pending.pending!.returnState,
      env: {
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
      },
      request: changedTargetRequest as typeof fetch,
    })).rejects.toThrow(/Invalid or expired/);
    expect(changedTargetRequest).not.toHaveBeenCalled();

    await completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-production",
      approvalCode: "approval-code",
      state: pending.pending!.returnState,
      env: productionEnv,
      request: request as typeof fetch,
    });
    const activeIdentity = loadPaperclipCloudConnectorIdentity()!;
    const activeSwitchRequest = vi.fn();
    const stagingEnv = {
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
    };

    await expect(startPaperclipCloudConnectorEnrollment({
      origin,
      env: stagingEnv,
      request: activeSwitchRequest as typeof fetch,
    })).rejects.toThrow(/another target/);
    expect(activeSwitchRequest).not.toHaveBeenCalled();
    expect(loadPaperclipCloudConnectorIdentity()).toEqual(activeIdentity);
    expect(bionicCloudConnectorConfigFromEnv(stagingEnv)).toBeNull();
  });

  it("treats managed environment identity as an atomic override of local identity", async () => {
    const origin = "https://private.example.test";
    const productionEnv = {
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.bionic.app",
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "production",
    };
    const request = vi.fn(async (input: string | URL | Request) => {
      if (String(input).endsWith("/v1/connector/enrollments")) {
        return Response.json({
          enrollmentId: "enroll-production",
          verificationUrl: "https://my.bionic.app/connections/enroll?id=enroll-production",
          expiresAt: new Date(Date.now() + 60_000).toISOString(),
        }, { status: 201 });
      }
      return Response.json({
        id: loadPaperclipCloudConnectorIdentity()?.instanceId,
        environment: "production",
        origins: [origin],
      });
    });
    await startPaperclipCloudConnectorEnrollment({ origin, env: productionEnv, request: request as typeof fetch });
    const pending = loadPaperclipCloudConnectorIdentity()!;
    await completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-production",
      approvalCode: "approval-code",
      state: pending.pending!.returnState,
      env: productionEnv,
      request: request as typeof fetch,
    });
    const localIdentity = loadPaperclipCloudConnectorIdentity()!;

    const managedEnv = {
      BIONIC_CLOUD_CONNECTOR_INSTANCE_ID: "managed-staging-instance",
      BIONIC_CLOUD_CONNECTOR_SIGN_PRIVATE_KEY: "managed-signing-key",
      BIONIC_CLOUD_CONNECTOR_SEAL_PRIVATE_KEY: "managed-sealing-key",
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
      BIONIC_PUBLIC_URL: "https://managed-stack.example.test",
    };
    expect(bionicCloudConnectorEnrollmentStatus(managedEnv)).toEqual({
      configured: true,
      status: "active",
      brokerBaseUrl: "https://my-staging.bionic.app",
      instanceId: "managed-staging-instance",
      environment: "staging",
      origins: ["https://managed-stack.example.test"],
    });
    expect(bionicCloudConnectorConfigFromEnv(managedEnv)).toMatchObject({
      baseUrl: "https://my-staging.bionic.app",
      instanceId: "managed-staging-instance",
      environment: "staging",
      signPrivateKey: "managed-signing-key",
      sealPrivateKey: "managed-sealing-key",
    });
    expect(loadPaperclipCloudConnectorIdentity()).toEqual(localIdentity);

    for (const omitted of [
      "BIONIC_CLOUD_CONNECTOR_INSTANCE_ID",
      "BIONIC_CLOUD_CONNECTOR_SIGN_PRIVATE_KEY",
      "BIONIC_CLOUD_CONNECTOR_SEAL_PRIVATE_KEY",
      "BIONIC_CLOUD_CONNECTOR_ENVIRONMENT",
    ] as const) {
      const partialManagedEnv: NodeJS.ProcessEnv = { ...managedEnv };
      delete partialManagedEnv[omitted];
      expect(bionicCloudConnectorEnrollmentStatus(partialManagedEnv)).toMatchObject({
        configured: false,
        status: "unverified",
        instanceId: null,
        environment: "staging",
      });
      expect(() => bionicCloudConnectorConfigFromEnv(partialManagedEnv)).toThrow(/incomplete/);
      expect(loadPaperclipCloudConnectorIdentity()).toEqual(localIdentity);
    }

    expect(bionicCloudConnectorConfigFromEnv(productionEnv)).toMatchObject({
      baseUrl: localIdentity.brokerBaseUrl,
      instanceId: localIdentity.instanceId,
      environment: localIdentity.environment,
      signPrivateKey: localIdentity.signPrivateKey,
      sealPrivateKey: localIdentity.sealPrivateKey,
    });
  });

  it("rejects known Cloud broker and environment mismatches", () => {
    const managedIdentity = {
      BIONIC_CLOUD_CONNECTOR_INSTANCE_ID: "managed-instance",
      BIONIC_CLOUD_CONNECTOR_SIGN_PRIVATE_KEY: "managed-signing-key",
      BIONIC_CLOUD_CONNECTOR_SEAL_PRIVATE_KEY: "managed-sealing-key",
    };
    const mismatches = [
      {
        ...managedIdentity,
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my.bionic.app",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
      },
      {
        ...managedIdentity,
        BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
        BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "production",
      },
    ];
    for (const env of mismatches) {
      expect(() => bionicCloudConnectorEnrollmentStatus(env)).toThrow(/do not match/);
      expect(() => bionicCloudConnectorConfigFromEnv(env)).toThrow(/do not match/);
    }
    expect(() => bionicCloudConnectorEnrollmentStatus({
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
    })).toThrow(/do not match/);
  });

  it("does not create or complete self-host enrollment with managed identity configuration", async () => {
    const origin = "https://private.example.test";
    const localEnv = {
      BIONIC_CLOUD_CONNECTOR_BASE_URL: "https://my-staging.bionic.app",
      BIONIC_CLOUD_CONNECTOR_ENVIRONMENT: "staging",
    };
    const enrollmentRequest = vi.fn(async () => Response.json({
      enrollmentId: "enroll-local",
      verificationUrl: "https://my-staging.bionic.app/connections/enroll?id=enroll-local",
      expiresAt: new Date(Date.now() + 60_000).toISOString(),
    }, { status: 201 }));
    await startPaperclipCloudConnectorEnrollment({
      origin,
      env: localEnv,
      request: enrollmentRequest as typeof fetch,
    });
    const pendingIdentity = loadPaperclipCloudConnectorIdentity()!;
    const managedEnv = {
      ...localEnv,
      BIONIC_CLOUD_CONNECTOR_INSTANCE_ID: "managed-staging-instance",
      BIONIC_CLOUD_CONNECTOR_SIGN_PRIVATE_KEY: "managed-signing-key",
      BIONIC_CLOUD_CONNECTOR_SEAL_PRIVATE_KEY: "managed-sealing-key",
    };
    const managedRequest = vi.fn();

    await expect(startPaperclipCloudConnectorEnrollment({
      origin,
      env: managedEnv,
      request: managedRequest as typeof fetch,
    })).rejects.toThrow(/unavailable with managed identity/);
    await expect(completePaperclipCloudConnectorEnrollment({
      enrollmentId: "enroll-local",
      approvalCode: "approval-code",
      state: pendingIdentity.pending!.returnState,
      env: managedEnv,
      request: managedRequest as typeof fetch,
    })).rejects.toThrow(/Invalid or expired/);
    expect(managedRequest).not.toHaveBeenCalled();
    expect(loadPaperclipCloudConnectorIdentity()).toEqual(pendingIdentity);
  });

  it("does not treat legacy Bionic ID keys as a Cloud enrollment", () => {
    expect(bionicCloudConnectorEnrollmentStatus({
      BIONIC_ID_CONNECTOR_INSTANCE_ID: "legacy-instance",
      BIONIC_ID_CONNECTOR_SIGN_PRIVATE_KEY: "legacy-signing-key",
      BIONIC_ID_CONNECTOR_SEAL_PRIVATE_KEY: "legacy-sealing-key",
      BIONIC_ID_CONNECTOR_ENVIRONMENT: "production",
      BIONIC_ID_CONNECTOR_BASE_URL: "https://id.bionic.app",
    })).toMatchObject({
      configured: false,
      status: "not_configured",
      brokerBaseUrl: "https://my.bionic.app",
      instanceId: null,
    });
  });
});
