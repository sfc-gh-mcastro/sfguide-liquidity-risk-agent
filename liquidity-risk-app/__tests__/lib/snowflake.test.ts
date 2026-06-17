import { describe, it, expect, vi, beforeEach, afterEach } from "vitest"
import fs from "fs"
import os from "os"
import path from "path"

import { readTomlDefaultConnection, resetTomlConfigCache } from "../../lib/snowflake"

// Mock fs and os so we control which files exist and their contents
vi.mock("fs")
vi.mock("os")

// smol-toml is loaded via require() inside the function; provide it via mock
vi.mock("smol-toml", () => {
  const { parse } = require("smol-toml") as { parse: (s: string) => Record<string, any> }
  return { parse }
})

const HOME = "/mock-home"

function setupFiles(files: Record<string, string>) {
  vi.mocked(os.homedir).mockReturnValue(HOME)
  vi.mocked(fs.existsSync).mockImplementation((p) => {
    return typeof p === "string" && p in files
  })
  vi.mocked(fs.readFileSync).mockImplementation((p, _enc) => {
    const content = files[String(p)]
    if (content === undefined) throw new Error(`ENOENT: ${p}`)
    return content
  })
}

const ENV_KEYS_TO_CLEAR = [
  "SNOWFLAKE_CONNECTION_NAME",
  "SNOWFLAKE_HOME",
  "SNOWFLAKE_ACCOUNT",
  "SNOWFLAKE_USER",
  "SNOWFLAKE_PASSWORD",
  "SNOWFLAKE_DATABASE",
  "SNOWFLAKE_SCHEMA",
  "SNOWFLAKE_ROLE",
  "SNOWFLAKE_WAREHOUSE",
]

beforeEach(() => {
  resetTomlConfigCache()
  for (const key of ENV_KEYS_TO_CLEAR) {
    delete process.env[key]
  }
})

afterEach(() => {
  vi.restoreAllMocks()
  // Clean up any extra env vars tests may have set
  delete process.env.SNOWFLAKE_RANDOM_KEY
})

describe("readTomlDefaultConnection", () => {
  it("returns null when neither file exists", () => {
    setupFiles({})
    expect(readTomlDefaultConnection()).toBeNull()
  })

  it("reads connections from connections.toml (legacy top-level format)", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        default_connection_name = "prod"
        [prod]
        account = "myaccount"
        user = "myuser"
        password = "mypass"
        warehouse = "mywh"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("myaccount")
    expect(conn!.user).toBe("myuser")
    expect(conn!.warehouse).toBe("mywh")
  })

  it("reads connections from config.toml legacy layout when connections.toml is absent", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "config.toml")]: `
        default_connection_name = "legacy"
        [connections.legacy]
        account = "legacy-acct"
        user = "legacy-user"
        password = "legacy-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("legacy-acct")
    expect(conn!.user).toBe("legacy-user")
  })

  it("prefers connections.toml over config.toml when both exist", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [modern]
        account = "modern-acct"
        user = "modern-user"
        password = "modern-pass"
      `,
      [path.join(HOME, ".snowflake", "config.toml")]: `
        [connections.legacy]
        account = "legacy-acct"
        user = "legacy-user"
        password = "legacy-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("modern-acct")
  })

  it("picks up default_connection_name from config.toml when connections.toml has none", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [alpha]
        account = "alpha-acct"
        user = "alpha-user"
        password = "alpha-pass"
        [beta]
        account = "beta-acct"
        user = "beta-user"
        password = "beta-pass"
      `,
      [path.join(HOME, ".snowflake", "config.toml")]: `
        default_connection_name = "beta"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("beta-acct")
  })

  it("SNOWFLAKE_CONNECTION_NAME env var overrides file defaults", () => {
    process.env.SNOWFLAKE_CONNECTION_NAME = "second"

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        default_connection_name = "first"
        [first]
        account = "first-acct"
        user = "first-user"
        password = "first-pass"
        [second]
        account = "second-acct"
        user = "second-user"
        password = "second-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("second-acct")
  })

  it("falls back to first connection when default name does not match any", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        default_connection_name = "nonexistent"
        [myconn]
        account = "fallback-acct"
        user = "fallback-user"
        password = "fallback-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("fallback-acct")
  })

  it("returns null when connections.toml exists but has no connection sections", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        default_connection_name = "foo"
      `,
    })

    expect(readTomlDefaultConnection()).toBeNull()
  })

  it("reads connections from connections.toml nested format [connections.name]", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [connections.prod]
        account = "nested-acct"
        user = "nested-user"
        password = "nested-pass"
      `,
    })

    process.env.SNOWFLAKE_CONNECTION_NAME = "prod"
    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("nested-acct")
  })

  it("nested [connections.*] format wins over legacy top-level on same name", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [test]
        account = "legacy-acct"
        user = "legacy-user"
        password = "legacy-pass"
        [connections.test]
        account = "nested-acct"
        user = "nested-user"
        password = "nested-pass"
      `,
    })

    process.env.SNOWFLAKE_CONNECTION_NAME = "test"
    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("nested-acct")
  })

  it("resolves legacy and nested connections coexisting in connections.toml", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [legacy_conn]
        account = "legacy-acct"
        user = "legacy-user"
        password = "legacy-pass"
        [connections.new_conn]
        account = "new-acct"
        user = "new-user"
        password = "new-pass"
      `,
    })

    process.env.SNOWFLAKE_CONNECTION_NAME = "new_conn"
    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("new-acct")
  })

  it("SNOWFLAKE_HOME changes the config file lookup directory", () => {
    process.env.SNOWFLAKE_HOME = "/custom-snowflake-dir"
    setupFiles({
      ["/custom-snowflake-dir/connections.toml"]: `
        [myconn]
        account = "custom-home-acct"
        user = "custom-home-user"
        password = "custom-home-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("custom-home-acct")
  })

  it("caches the result across calls", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [cached]
        account = "cached-acct"
        user = "cached-user"
        password = "cached-pass"
      `,
    })

    const first = readTomlDefaultConnection()
    // Change the mock -- should NOT affect result due to caching
    vi.mocked(fs.existsSync).mockReturnValue(false)
    const second = readTomlDefaultConnection()

    expect(first).toEqual(second)
    expect(second!.account).toBe("cached-acct")
  })

  it("cache is cleared by resetTomlConfigCache", () => {
    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [v1]
        account = "v1-acct"
        user = "v1-user"
        password = "v1-pass"
      `,
    })

    const first = readTomlDefaultConnection()
    expect(first!.account).toBe("v1-acct")

    resetTomlConfigCache()

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [v2]
        account = "v2-acct"
        user = "v2-user"
        password = "v2-pass"
      `,
    })

    const second = readTomlDefaultConnection()
    expect(second!.account).toBe("v2-acct")
  })

  // --- Env var overlay tests (spec §3.B) ---

  it("SNOWFLAKE_ACCOUNT env var overlays on toml connection", () => {
    process.env.SNOWFLAKE_ACCOUNT = "env-override-acct"

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [myconn]
        account = "file-acct"
        user = "file-user"
        password = "file-pass"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("env-override-acct")
    expect(conn!.user).toBe("file-user") // non-overridden field preserved
  })

  it("multiple SNOWFLAKE_<KEY> env vars overlay on toml connection", () => {
    process.env.SNOWFLAKE_DATABASE = "env-db"
    process.env.SNOWFLAKE_SCHEMA = "env-schema"
    process.env.SNOWFLAKE_ROLE = "env-role"

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [myconn]
        account = "file-acct"
        user = "file-user"
        database = "file-db"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("file-acct") // not overridden
    expect(conn!.database).toBe("env-db")
    expect(conn!.schema).toBe("env-schema")
    expect(conn!.role).toBe("env-role")
  })

  it("env var overlay applies to all connections in cache", () => {
    process.env.SNOWFLAKE_WAREHOUSE = "env-warehouse"

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [conn1]
        account = "acct1"
        user = "user1"
        [conn2]
        account = "acct2"
        user = "user2"
      `,
    })

    // First call caches both connections with overlay applied
    process.env.SNOWFLAKE_CONNECTION_NAME = "conn1"
    const conn1 = readTomlDefaultConnection()
    expect(conn1!.warehouse).toBe("env-warehouse")

    // Switch to conn2 (still uses cache)
    process.env.SNOWFLAKE_CONNECTION_NAME = "conn2"
    resetTomlConfigCache()

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [conn1]
        account = "acct1"
        user = "user1"
        [conn2]
        account = "acct2"
        user = "user2"
      `,
    })

    const conn2 = readTomlDefaultConnection()
    expect(conn2!.warehouse).toBe("env-warehouse")
    expect(conn2!.account).toBe("acct2")
  })

  it("ignores non-connection SNOWFLAKE_* env vars", () => {
    process.env.SNOWFLAKE_CONNECTION_NAME = "myconn"
    process.env.SNOWFLAKE_RANDOM_KEY = "ignored"

    setupFiles({
      [path.join(HOME, ".snowflake", "connections.toml")]: `
        [myconn]
        account = "file-acct"
        user = "file-user"
      `,
    })

    const conn = readTomlDefaultConnection()
    expect(conn).not.toBeNull()
    expect(conn!.account).toBe("file-acct")
    expect((conn as Record<string, unknown>).random_key).toBeUndefined()
  })
})
