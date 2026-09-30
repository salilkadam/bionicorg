import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterEach, describe, expect, it } from "vitest";
import { ensureCodexSkillsInjected } from "@bionicai/adapter-codex-local/server";

async function makeTempDir(prefix: string): Promise<string> {
  return fs.mkdtemp(path.join(os.tmpdir(), prefix));
}

async function createPaperclipRepoSkill(root: string, skillName: string) {
  await fs.mkdir(path.join(root, "server"), { recursive: true });
  await fs.mkdir(path.join(root, "packages", "adapter-utils"), { recursive: true });
  await fs.mkdir(path.join(root, "skills", skillName), { recursive: true });
  await fs.writeFile(path.join(root, "pnpm-workspace.yaml"), "packages:\n  - packages/*\n", "utf8");
  await fs.writeFile(path.join(root, "package.json"), '{"name":"bionic"}\n', "utf8");
  await fs.writeFile(
    path.join(root, "skills", skillName, "SKILL.md"),
    `---\nname: ${skillName}\n---\n`,
    "utf8",
  );
}

async function createCustomSkill(root: string, skillName: string) {
  await fs.mkdir(path.join(root, "custom", skillName), { recursive: true });
  await fs.writeFile(
    path.join(root, "custom", skillName, "SKILL.md"),
    `---\nname: ${skillName}\n---\n`,
    "utf8",
  );
}

describe("codex local adapter skill injection", () => {
  const bionicKey = "bionicai/bionic/bionic";
  const createAgentKey = "bionicai/bionic/bionic-create-agent";
  const cleanupDirs = new Set<string>();

  afterEach(async () => {
    await Promise.all(Array.from(cleanupDirs).map((dir) => fs.rm(dir, { recursive: true, force: true })));
    cleanupDirs.clear();
  });

  it("repairs a Codex Bionic skill symlink that still points at another live checkout", async () => {
    const currentRepo = await makeTempDir("bionic-codex-current-");
    const oldRepo = await makeTempDir("bionic-codex-old-");
    const skillsHome = await makeTempDir("bionic-codex-home-");
    cleanupDirs.add(currentRepo);
    cleanupDirs.add(oldRepo);
    cleanupDirs.add(skillsHome);

    await createPaperclipRepoSkill(currentRepo, "bionic");
    await createPaperclipRepoSkill(currentRepo, "bionic-create-agent");
    await createPaperclipRepoSkill(oldRepo, "bionic");
    await fs.symlink(path.join(oldRepo, "skills", "bionic"), path.join(skillsHome, "bionic"));

    const logs: Array<{ stream: "stdout" | "stderr"; chunk: string }> = [];
    await ensureCodexSkillsInjected(
      async (stream, chunk) => {
        logs.push({ stream, chunk });
      },
      {
        skillsHome,
        skillsEntries: [
          {
            key: bionicKey,
            runtimeName: "bionic",
            source: path.join(currentRepo, "skills", "bionic"),
          },
          {
            key: createAgentKey,
            runtimeName: "bionic-create-agent",
            source: path.join(currentRepo, "skills", "bionic-create-agent"),
          },
        ],
      },
    );

    expect(await fs.realpath(path.join(skillsHome, "bionic"))).toBe(
      await fs.realpath(path.join(currentRepo, "skills", "bionic")),
    );
    expect(await fs.realpath(path.join(skillsHome, "bionic-create-agent"))).toBe(
      await fs.realpath(path.join(currentRepo, "skills", "bionic-create-agent")),
    );
    expect(logs).toContainEqual(
      expect.objectContaining({
        stream: "stdout",
        chunk: expect.stringContaining('Repaired Codex skill "bionic"'),
      }),
    );
    expect(logs).toContainEqual(
      expect.objectContaining({
        stream: "stdout",
        chunk: expect.stringContaining('Injected Codex skill "bionic-create-agent"'),
      }),
    );
  });

  it("preserves a custom Codex skill symlink outside Bionic repo checkouts", async () => {
    const currentRepo = await makeTempDir("bionic-codex-current-");
    const customRoot = await makeTempDir("bionic-codex-custom-");
    const skillsHome = await makeTempDir("bionic-codex-home-");
    cleanupDirs.add(currentRepo);
    cleanupDirs.add(customRoot);
    cleanupDirs.add(skillsHome);

    await createPaperclipRepoSkill(currentRepo, "bionic");
    await createCustomSkill(customRoot, "bionic");
    await fs.symlink(path.join(customRoot, "custom", "bionic"), path.join(skillsHome, "bionic"));

    await ensureCodexSkillsInjected(async () => {}, {
      skillsHome,
      skillsEntries: [{
        key: bionicKey,
        runtimeName: "bionic",
        source: path.join(currentRepo, "skills", "bionic"),
      }],
    });

    expect(await fs.realpath(path.join(skillsHome, "bionic"))).toBe(
      await fs.realpath(path.join(customRoot, "custom", "bionic")),
    );
  });

  it("prunes broken symlinks for unavailable Bionic repo skills before Codex starts", async () => {
    const currentRepo = await makeTempDir("bionic-codex-current-");
    const oldRepo = await makeTempDir("bionic-codex-old-");
    const skillsHome = await makeTempDir("bionic-codex-home-");
    cleanupDirs.add(currentRepo);
    cleanupDirs.add(oldRepo);
    cleanupDirs.add(skillsHome);

    await createPaperclipRepoSkill(currentRepo, "bionic");
    await createPaperclipRepoSkill(oldRepo, "agent-browser");
    const staleTarget = path.join(oldRepo, "skills", "agent-browser");
    await fs.symlink(staleTarget, path.join(skillsHome, "agent-browser"));
    await fs.rm(staleTarget, { recursive: true, force: true });

    const logs: Array<{ stream: "stdout" | "stderr"; chunk: string }> = [];
    await ensureCodexSkillsInjected(
      async (stream, chunk) => {
        logs.push({ stream, chunk });
      },
      {
        skillsHome,
        skillsEntries: [{
          key: bionicKey,
          runtimeName: "bionic",
          source: path.join(currentRepo, "skills", "bionic"),
        }],
      },
    );

    await expect(fs.lstat(path.join(skillsHome, "agent-browser"))).rejects.toMatchObject({
      code: "ENOENT",
    });
    expect(logs).toContainEqual(
      expect.objectContaining({
        stream: "stdout",
        chunk: expect.stringContaining('Removed stale Codex skill "agent-browser"'),
      }),
    );
  });

  it("preserves other live Bionic skill symlinks in the shared workspace skill directory", async () => {
    const currentRepo = await makeTempDir("bionic-codex-current-");
    const skillsHome = await makeTempDir("bionic-codex-home-");
    cleanupDirs.add(currentRepo);
    cleanupDirs.add(skillsHome);

    await createPaperclipRepoSkill(currentRepo, "bionic");
    await createPaperclipRepoSkill(currentRepo, "agent-browser");
    await fs.symlink(
      path.join(currentRepo, "skills", "agent-browser"),
      path.join(skillsHome, "agent-browser"),
    );

    await ensureCodexSkillsInjected(async () => {}, {
      skillsHome,
      skillsEntries: [{
        key: bionicKey,
        runtimeName: "bionic",
        source: path.join(currentRepo, "skills", "bionic"),
      }],
    });

    expect((await fs.lstat(path.join(skillsHome, "bionic"))).isSymbolicLink()).toBe(true);
    expect((await fs.lstat(path.join(skillsHome, "agent-browser"))).isSymbolicLink()).toBe(true);
    expect(await fs.realpath(path.join(skillsHome, "agent-browser"))).toBe(
      await fs.realpath(path.join(currentRepo, "skills", "agent-browser")),
    );
  });
});
