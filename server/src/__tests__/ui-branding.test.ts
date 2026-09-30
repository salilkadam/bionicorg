import { describe, expect, it } from "vitest";
import {
  applyUiBranding,
  getWorktreeUiBranding,
  isWorktreeUiBrandingEnabled,
  renderFaviconLinks,
  renderRuntimeBrandingMeta,
} from "../ui-branding.js";

const TEMPLATE = `<!doctype html>
<head>
    <!-- BIONIC_RUNTIME_BRANDING_START -->
    <!-- BIONIC_RUNTIME_BRANDING_END -->
    <!-- BIONIC_FAVICON_START -->
    <link rel="icon" href="/favicon.ico" sizes="48x48" />
    <link rel="icon" href="/favicon.svg" type="image/svg+xml" />
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png" />
    <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png" />
    <!-- BIONIC_FAVICON_END -->
</head>`;

describe("ui branding", () => {
  it("detects worktree mode from BIONIC_IN_WORKTREE", () => {
    expect(isWorktreeUiBrandingEnabled({ BIONIC_IN_WORKTREE: "true" })).toBe(true);
    expect(isWorktreeUiBrandingEnabled({ BIONIC_IN_WORKTREE: "1" })).toBe(true);
    expect(isWorktreeUiBrandingEnabled({ BIONIC_IN_WORKTREE: "false" })).toBe(false);
  });

  it("resolves name, color, and text color for worktree branding", () => {
    const branding = getWorktreeUiBranding({
      BIONIC_IN_WORKTREE: "true",
      BIONIC_WORKTREE_NAME: "bionic-pr-432",
      BIONIC_WORKTREE_COLOR: "#4f86f7",
    });

    expect(branding.enabled).toBe(true);
    expect(branding.name).toBe("bionic-pr-432");
    expect(branding.color).toBe("#4f86f7");
    expect(branding.textColor).toMatch(/^#[0-9a-f]{6}$/);
    expect(branding.faviconHref).toContain("data:image/svg+xml,");
  });

  it("renders a dynamic worktree favicon when enabled", () => {
    const links = renderFaviconLinks(
      getWorktreeUiBranding({
        BIONIC_IN_WORKTREE: "true",
        BIONIC_WORKTREE_NAME: "bionic-pr-432",
        BIONIC_WORKTREE_COLOR: "#4f86f7",
      }),
    );
    expect(links).toContain("data:image/svg+xml,");
    expect(links).toContain('rel="shortcut icon"');
  });

  it("renders runtime branding metadata for the ui", () => {
    const meta = renderRuntimeBrandingMeta(
      getWorktreeUiBranding({
        BIONIC_IN_WORKTREE: "true",
        BIONIC_WORKTREE_NAME: "bionic-pr-432",
        BIONIC_WORKTREE_COLOR: "#4f86f7",
      }),
    );
    expect(meta).toContain('name="bionic-worktree-name"');
    expect(meta).toContain('content="bionic-pr-432"');
    expect(meta).toContain('name="bionic-worktree-color"');
  });

  it("surfaces the runtime instance id so the UI can fail closed on copied rows", () => {
    const branding = getWorktreeUiBranding({
      BIONIC_IN_WORKTREE: "true",
      BIONIC_WORKTREE_NAME: "bionic-pr-432",
      BIONIC_WORKTREE_COLOR: "#4f86f7",
      BIONIC_INSTANCE_ID: "inst-abc123",
    });
    expect(branding.instanceId).toBe("inst-abc123");

    const meta = renderRuntimeBrandingMeta(branding);
    expect(meta).toContain('name="bionic-instance-id"');
    expect(meta).toContain('content="inst-abc123"');
  });

  it("omits the instance-id meta when the runtime id is unset", () => {
    const branding = getWorktreeUiBranding({
      BIONIC_IN_WORKTREE: "true",
      BIONIC_WORKTREE_NAME: "bionic-pr-432",
      BIONIC_WORKTREE_COLOR: "#4f86f7",
    });
    expect(branding.instanceId).toBeNull();
    expect(renderRuntimeBrandingMeta(branding)).not.toContain('name="bionic-instance-id"');
  });

  it("rewrites the favicon and runtime branding blocks for worktree instances only", () => {
    const branded = applyUiBranding(TEMPLATE, {
      BIONIC_IN_WORKTREE: "true",
      BIONIC_WORKTREE_NAME: "bionic-pr-432",
      BIONIC_WORKTREE_COLOR: "#4f86f7",
    });
    expect(branded).toContain("data:image/svg+xml,");
    expect(branded).toContain('name="bionic-worktree-name"');
    expect(branded).not.toContain('href="/favicon.svg"');

    const defaultHtml = applyUiBranding(TEMPLATE, {});
    expect(defaultHtml).toContain('href="/favicon.svg"');
    expect(defaultHtml).not.toContain('name="bionic-worktree-name"');
  });
});
