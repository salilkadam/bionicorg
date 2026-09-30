import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import {
  listCodexSkills,
  syncCodexSkills,
} from "@bionicai/adapter-codex-local/server";

async function makeTempDir(prefix: string): Promise<string> {
  return fs.mkdtemp(path.join(os.tmpdir(), prefix));
}

describe("codex local skill sync", () => {
  const bionicKey = "bionicai/bionic/bionic";
  const cleanupDirs = new Set<string>();

  afterEach(async () => {
    await Promise.all(Array.from(cleanupDirs).map((dir) => fs.rm(dir, { recursive: true, force: true })));
    cleanupDirs.clear();
  });

  it("defaults the operational Bionic skill for workspace injection on the next run", async () => {
    const codexHome = await makeTempDir("bionic-codex-skill-sync-");
    cleanupDirs.add(codexHome);

    const ctx = {
      agentId: "agent-1",
      companyId: "company-1",
      adapterType: "codex_local",
      config: {
        env: {
          CODEX_HOME: codexHome,
        },
      },
    } as const;

    const before = await listCodexSkills(ctx);
    expect(before.mode).toBe("ephemeral");
    expect(before.desiredSkills).toContain(bionicKey);
    expect(before.entries.find((entry) => entry.key === bionicKey)?.state).toBe("configured");
    expect(before.entries.find((entry) => entry.key === bionicKey)?.detail).toContain("CODEX_HOME/skills/");
  });

  it("does not apply the legacy operational skill default to the native runner", async () => {
    const snapshot = await listCodexSkills({
      agentId: "agent-native",
      companyId: "company-1",
      adapterType: "bionic_runner",
      config: {},
    });

    expect(snapshot.adapterType).toBe("bionic_runner");
    expect(snapshot.desiredSkills).toEqual([]);
    expect(snapshot.entries.find((entry) => entry.key === bionicKey)?.state).toBe("available");
  });

  it("does not persist Bionic skills into CODEX_HOME during sync", async () => {
    const codexHome = await makeTempDir("bionic-codex-skill-prune-");
    cleanupDirs.add(codexHome);

    const configuredCtx = {
      agentId: "agent-2",
      companyId: "company-1",
      adapterType: "codex_local",
      config: {
        env: {
          CODEX_HOME: codexHome,
        },
        bionicSkillSync: {
          desiredSkills: [bionicKey],
        },
      },
    } as const;

    const after = await syncCodexSkills(configuredCtx, [bionicKey]);
    expect(after.mode).toBe("ephemeral");
    expect(after.entries.find((entry) => entry.key === bionicKey)?.state).toBe("configured");
    await expect(fs.lstat(path.join(codexHome, "skills", "bionic"))).rejects.toMatchObject({
      code: "ENOENT",
    });
  });

  it("normalizes legacy flat Bionic skill refs before reporting configured state", async () => {
    const codexHome = await makeTempDir("bionic-codex-legacy-skill-sync-");
    cleanupDirs.add(codexHome);

    const snapshot = await listCodexSkills({
      agentId: "agent-3",
      companyId: "company-1",
      adapterType: "codex_local",
      config: {
        env: {
          CODEX_HOME: codexHome,
        },
        bionicSkillSync: {
          desiredSkills: ["bionic"],
        },
      },
    });

    expect(snapshot.warnings).toEqual([]);
    expect(snapshot.desiredSkills).toContain(bionicKey);
    expect(snapshot.desiredSkills).not.toContain("bionic");
    expect(snapshot.entries.find((entry) => entry.key === bionicKey)?.state).toBe("configured");
    expect(snapshot.entries.find((entry) => entry.key === "bionic")).toBeUndefined();
  });
});
