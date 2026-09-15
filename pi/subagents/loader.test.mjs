import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { stripTypeScriptTypes } from 'node:module';

const installed = resolve(process.env.PI_SUBAGENTS_PACKAGE ?? `${process.env.HOME}/.pi/agent/npm/node_modules/pi-subagents`);
const original = readFileSync(join(installed, 'src/runs/shared/child-tool-plan.ts'), 'utf8');

test('loader patches a separate copy and reuses stable child paths', async () => {
  const home = mkdtempSync(join(tmpdir(), 'pi-subagent-loader-'));
  try {
    const pkg = join(home, 'npm/node_modules/pi-subagents');
    mkdirSync(join(pkg, 'src/runs/shared'), { recursive: true });
    writeFileSync(join(pkg, 'package.json'), JSON.stringify({ type: 'module', version: 'test' }));
    writeFileSync(join(pkg, 'src/runs/shared/child-tool-plan.ts'), original);
    writeFileSync(join(pkg, 'index.ts'), 'export default function(pi) { pi.loaded.push(import.meta.url); }');
    let code = stripTypeScriptTypes(readFileSync(resolve(import.meta.dirname, '../extensions/subagents.ts'), 'utf8'));
    code = code.replace('from "@earendil-works/pi-coding-agent"', `from ${JSON.stringify('data:text/javascript,' + encodeURIComponent(`export const getAgentDir = () => ${JSON.stringify(home)};`))}`);
    code = code.replaceAll('@patch@', 'patch').replaceAll('@toolPatch@', resolve(import.meta.dirname, 'tool-availability.patch'));
    const entry = join(home, 'loader.mjs');
    writeFileSync(entry, code);
    const { default: load } = await import(pathToFileURL(entry));
    const pi = { loaded: [] };
    await load(pi);
    await load(pi);
    assert.equal(pi.loaded.length, 2);
    assert.equal(pi.loaded[0], pi.loaded[1]);
    assert.ok(pi.loaded[0].includes('/.subagent-patches/'));
    assert.equal(readFileSync(join(pkg, 'src/runs/shared/child-tool-plan.ts'), 'utf8'), original);
    const cache = join(home, 'npm/.subagent-patches');
    const entries = readdirSync(cache);
    assert.equal(entries.length, 1);
    const patched = readFileSync(join(cache, entries[0], 'src/runs/shared/child-tool-plan.ts'), 'utf8');
    assert.ok(patched.includes('!PI_BUILTIN_TOOL_NAMES.has(tool) || hostAvailableSet.has(tool)'));
    // An incompatible package update must not silently load the old copy.
    writeFileSync(join(pkg, 'src/runs/shared/child-tool-plan.ts'), 'incompatible source');
    await assert.rejects(load(pi), /Tool availability patch failed/);
    assert.equal(pi.loaded.length, 2);
    assert.deepEqual(readdirSync(cache), entries);
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});
