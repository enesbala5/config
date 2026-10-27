#!/usr/bin/env node
// Sync the canonical MCP server list into every client that can't read it directly.
//
//   canonical   ~/config/misc/mcp/mcp.json        (tracked, ${VAR} placeholders)
//   secrets     /run/agenix/mcp-secrets.json      (agenix; override with MCP_SECRETS)
//
//   -> ~/.pi/agent/mcp.json        Cursor-schema clone, pi keys kept
//   -> ~/.cursor/mcp.json          same schema, pi-only keys stripped
//   -> ~/.config/zed/settings.json "context_servers" replaced in place, comments preserved
//
// opencode is handled by nix: nix/nixos/modules/home/programs/opencode/mcp.nix reads
// the canonical file at eval time and rewrites ${VAR} to {env:VAR}.
//
// Usage: mcp-sync.mjs [--check]

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const HOME = os.homedir();
const CONFIG_DIR = process.env.MCP_CONFIG_DIR || path.join(HOME, "config");

const canonicalPath = path.join(CONFIG_DIR, "misc/mcp/mcp.json");
const secretsPath = process.env.MCP_SECRETS || "/run/agenix/mcp-secrets.json";

const piPath = path.join(HOME, ".pi/agent/mcp.json");
const cursorPath = path.join(HOME, ".cursor/mcp.json");
const zedPath = path.join(HOME, ".config/zed/settings.json");

const PI_ONLY_KEYS = new Set(["exposure", "description", "oauth"]);
const NAME_RE = /^[A-Za-z0-9_-]+$/;
const check = process.argv.includes("--check");

const warnings = [];
const changes = [];

function loadJson(file, what) {
  if (!fs.existsSync(file)) {
    if (what === "secrets") return {};
    throw new Error(`missing ${what}: ${file}`);
  }
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function expand(value, env, trail = "") {
  if (typeof value === "string") {
    return value.replace(/\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g, (_, name) => {
      const v = env[name];
      if (v === undefined || v === "") {
        throw new Error(`unresolved \${${name}} in ${trail || "config"} (add it to ${secretsPath} or export it)`);
      }
      return v;
    });
  }
  if (Array.isArray(value)) return value.map((v, i) => expand(v, env, `${trail}[${i}]`));
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, expand(v, env, trail ? `${trail}.${k}` : k)]));
  }
  return value;
}

function withoutKeys(server) {
  return Object.fromEntries(Object.entries(server).filter(([k]) => !PI_ONLY_KEYS.has(k)));
}

function writeJson(file, data) {
  const next = JSON.stringify(data, null, 2) + "\n";
  const prev = fs.existsSync(file) ? fs.readFileSync(file, "utf8") : null;
  if (prev === next) return false;
  if (!check) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, next);
  }
  changes.push(file);
  return true;
}

// --- minimal JSONC scanner, enough to replace one top-level value in place ---

function findValueEnd(text, start) {
  let depth = 0;
  for (let i = start; i < text.length; i++) {
    const c = text[i];
    if (c === '"') {
      i++;
      while (i < text.length) {
        if (text[i] === "\\") i += 2;
        else if (text[i] === '"') break;
        else i++;
      }
      if (depth === 0) return i + 1;
      continue;
    }
    if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      continue;
    }
    if (c === "/" && text[i + 1] === "*") {
      i += 2;
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i++;
      i++;
      continue;
    }
    if (c === "{" || c === "[") depth++;
    else if (c === "}" || c === "]") {
      if (depth === 0) return i;
      depth--;
      if (depth === 0) return i + 1;
    } else if (depth === 0 && (c === "," || c === "\n" || c === " " || c === "\t" || c === "\r")) {
      if (c === ",") return i;
    }
  }
  throw new Error("unterminated value");
}

function replaceTopLevelValue(text, key, value) {
  const rendered = JSON.stringify(value, null, "\t").replace(/\n/g, "\n\t");
  let depth = 0;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (c === "/" && text[i + 1] === "/") {
      while (i < text.length && text[i] !== "\n") i++;
      continue;
    }
    if (c === "/" && text[i + 1] === "*") {
      i += 2;
      while (i < text.length && !(text[i] === "*" && text[i + 1] === "/")) i++;
      i++;
      continue;
    }
    if (c === '"') {
      let j = i + 1;
      while (j < text.length) {
        if (text[j] === "\\") j += 2;
        else if (text[j] === '"') break;
        else j++;
      }
      const str = text.slice(i + 1, j);
      if (depth === 1 && str === key) {
        let k = j + 1;
        while (k < text.length && /\s/.test(text[k])) k++;
        if (text[k] !== ":") throw new Error(`malformed settings.json near "${key}"`);
        k++;
        while (k < text.length && /\s/.test(text[k])) k++;
        const end = findValueEnd(text, k);
        return text.slice(0, k) + rendered + text.slice(end);
      }
      i = j;
      continue;
    }
    if (c === "{" || c === "[") depth++;
    else if (c === "}" || c === "]") depth--;
  }
  // absent: insert before the root object's closing brace
  const close = text.lastIndexOf("}");
  const needsComma = /[^,{\s]/.test(text.slice(0, close).replace(/\/\/[^\n]*/g, "").trimEnd().slice(-1));
  const body = text.slice(0, close).replace(/\s*$/, "");
  return `${body}${needsComma ? "," : ""}\n\t"${key}": ${rendered}\n${text.slice(close)}`;
}

// --- main ---

const canonical = loadJson(canonicalPath, "canonical config");
const env = { ...JSON.parse(JSON.stringify(loadJson(secretsPath, "secrets"))), ...process.env };
const servers = expand(canonical.mcpServers, env, "");

for (const [name, server] of Object.entries(servers)) {
  if (!NAME_RE.test(name)) {
    throw new Error(`invalid server name "${name}" (pi allows only letters, digits, "_" and "-")`);
  }
  if (!server.command && !server.url) {
    throw new Error(`server "${name}" needs either "command" or "url"`);
  }
}

const enabled = Object.fromEntries(Object.entries(servers).filter(([, s]) => s.enabled !== false));
const disabled = Object.keys(servers).filter((n) => !(n in enabled));
if (disabled.length) warnings.push(`disabled (not written to Cursor/Zed/opencode): ${disabled.join(", ")}`);

// pi reads pi-only keys (exposure, description, oauth)
writeJson(piPath, { mcpServers: servers });

// Cursor: identical schema minus pi-only keys
writeJson(cursorPath, { mcpServers: Object.fromEntries(Object.entries(enabled).map(([n, s]) => [n, withoutKeys(s)])) });

// Zed: context_servers live inside settings.json, which is JSONC and hand-edited
const zedServers = {};
for (const [name, s] of Object.entries(enabled)) {
  zedServers[name] = s.command
    ? { command: s.command, args: s.args ?? [], env: s.env ?? {}, enabled: true }
    : { url: s.url, ...(s.headers ? { headers: s.headers } : {}), enabled: true };
}
if (fs.existsSync(zedPath)) {
  const before = fs.readFileSync(zedPath, "utf8");
  const after = replaceTopLevelValue(before, "context_servers", zedServers);
  if (after !== before) {
    if (!check) fs.writeFileSync(zedPath, after);
    changes.push(zedPath);
  }
} else {
  warnings.push(`no ${zedPath}, skipped Zed`);
}

if (changes.length) {
  console.log(`${check ? "would update" : "updated"}:`);
  for (const c of changes) console.log(`  ${c}`);
} else {
  console.log("already up to date");
}
for (const w of warnings) console.log(`note: ${w}`);
