import os from "node:os";
import path from "node:path";
import { describe, expect, it } from "vitest";
import { applyDevRunnerOptions } from "../../../scripts/dev-runner-options.ts";

describe("applyDevRunnerOptions", () => {
  it("turns --data-dir into isolated Bionic paths and consumes the option", () => {
    const env: NodeJS.ProcessEnv = {};
    const cwd = path.join(os.tmpdir(), "bionic-dev-runner-options");
    const previousInstanceId = process.env.BIONIC_INSTANCE_ID;
    process.env.BIONIC_INSTANCE_ID = "ambient-test-instance";

    try {
      const result = applyDevRunnerOptions(
        ["--bind", "loopback", "--data-dir", "./tmp", "--future-option"],
        env,
        cwd,
      );

      const expectedHome = path.resolve(cwd, "tmp");
      expect(result).toEqual({
        forwardedArgs: ["--bind", "loopback", "--future-option"],
        dataDir: expectedHome,
      });
      expect(env.BIONIC_HOME).toBe(expectedHome);
      expect(env.BIONIC_INSTANCE_ID).toBe("default");
      expect(env.BIONIC_CONFIG).toBe(
        path.join(expectedHome, "instances", "default", "config.json"),
      );
      expect(env.BIONIC_CONTEXT).toBe(path.join(expectedHome, "context.json"));
    } finally {
      if (previousInstanceId === undefined) {
        delete process.env.BIONIC_INSTANCE_ID;
      } else {
        process.env.BIONIC_INSTANCE_ID = previousInstanceId;
      }
    }
  });

  it.each([
    ["short option", ["-d", "~/bionic-dev"]],
    ["equals form", ["--data-dir=~/bionic-dev"]],
  ])("supports the %s", (_label, args) => {
    const env: NodeJS.ProcessEnv = {};

    const result = applyDevRunnerOptions(args, env, "/unused");

    expect(result.forwardedArgs).toEqual([]);
    expect(result.dataDir).toBe(path.join(os.homedir(), "bionic-dev"));
  });

  it("uses the selected instance for the default config path", () => {
    const env: NodeJS.ProcessEnv = { BIONIC_INSTANCE_ID: "experiment" };

    applyDevRunnerOptions(["--data-dir", "/isolated/home"], env, "/unused");

    expect(env.BIONIC_CONFIG).toBe(
      path.join("/isolated/home", "instances", "experiment", "config.json"),
    );
  });

  it("preserves explicit config and context paths", () => {
    const env: NodeJS.ProcessEnv = {
      BIONIC_CONFIG: "/explicit/config.json",
      BIONIC_CONTEXT: "/explicit/context.json",
    };

    applyDevRunnerOptions(["--data-dir", "/isolated/home"], env, "/unused");

    expect(env.BIONIC_HOME).toBe("/isolated/home");
    expect(env.BIONIC_CONFIG).toBe("/explicit/config.json");
    expect(env.BIONIC_CONTEXT).toBe("/explicit/context.json");
  });

  it.each([["--data-dir"], ["-d"], ["--data-dir="]])(
    "rejects a missing value for %s",
    (...args) => {
      expect(() => applyDevRunnerOptions(args, {}, "/unused")).toThrow(
        /requires a value/,
      );
    },
  );
});
