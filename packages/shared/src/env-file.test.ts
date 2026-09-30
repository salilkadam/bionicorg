import { describe, expect, it } from "vitest";
import { encodeEnvValue, updateEnvFileContents } from "./env-file.js";

describe("env file editor", () => {
  it("pins minimal and JSON value encoding", () => {
    expect(encodeEnvValue("plain-value", "minimal")).toBe("plain-value");
    expect(encodeEnvValue("#439edb", "minimal")).toBe('"#439edb"');
    expect(encodeEnvValue("plain-value", "json")).toBe('"plain-value"');
  });

  it("preserves unrelated content and CRLF while updating every stale duplicate", () => {
    const original = [
      "# operator comment",
      "UNKNOWN='keep this encoding'",
      "",
      "export BIONIC_HOME = '/old path'  # managed path",
      "BIONIC_DUPLICATE=stale",
      'BIONIC_DUPLICATE="current"',
      "TRAILING=untouched",
      "",
    ].join("\r\n");

    const updated = updateEnvFileContents(
      original,
      {
        BIONIC_HOME: "/new path",
        BIONIC_DUPLICATE: "current",
        BIONIC_WORKTREE_COLOR: "#439edb",
      },
      { valueEncoding: "minimal" },
    );

    expect(updated).toBe([
      "# operator comment",
      "UNKNOWN='keep this encoding'",
      "",
      'export BIONIC_HOME = "/new path"  # managed path',
      "BIONIC_DUPLICATE=current",
      'BIONIC_DUPLICATE="current"',
      "TRAILING=untouched",
      'BIONIC_WORKTREE_COLOR="#439edb"',
      "",
    ].join("\r\n"));
    expect(updated.replaceAll("\r\n", "")).not.toContain("\n");
  });

  it("uses JSON encoding for changed values without re-encoding current assignments", () => {
    const original = [
      "BIONIC_CURRENT=plain-value",
      "BIONIC_CHANGED=old",
      "UNKNOWN=\"operator value\"",
      "",
    ].join("\n");

    expect(
      updateEnvFileContents(
        original,
        {
          BIONIC_CURRENT: "plain-value",
          BIONIC_CHANGED: "new",
          BIONIC_ADDED: "added",
        },
        { valueEncoding: "json" },
      ),
    ).toBe([
      "BIONIC_CURRENT=plain-value",
      'BIONIC_CHANGED="new"',
      'UNKNOWN="operator value"',
      'BIONIC_ADDED="added"',
      "",
    ].join("\n"));
  });

  it("does not treat an unquoted dotenv comment as the managed value", () => {
    expect(
      updateEnvFileContents(
        ["BIONIC_COLOR=#439edb", "BIONIC_HOME=old# keep this comment"].join("\n"),
        {
          BIONIC_COLOR: "#439edb",
          BIONIC_HOME: "new",
        },
        { valueEncoding: "minimal" },
      ),
    ).toBe(
      ['BIONIC_COLOR="#439edb"#439edb', "BIONIC_HOME=new# keep this comment"].join("\n"),
    );
  });

  it("is a no-op when every managed duplicate is already current", () => {
    const original = [
      "export BIONIC_HOME = '/same path' # first",
      'BIONIC_HOME="/same path"',
      "UNKNOWN=value",
    ].join("\n");

    expect(updateEnvFileContents(original, { BIONIC_HOME: "/same path" })).toBe(original);
  });
});
