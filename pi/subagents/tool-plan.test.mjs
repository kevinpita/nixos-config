import assert from 'node:assert/strict';
import { readFileSync, mkdtempSync, cpSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { stripTypeScriptTypes } from 'node:module';
import { execFileSync } from 'node:child_process';
import { test } from 'node:test';

// Exercise the installed planner, not a reimplementation. Stub only unrelated
// MCP discovery and configuration imports. Capability checks use the real module.
const packageDir = resolve(process.env.PI_SUBAGENTS_PACKAGE ?? `${process.env.HOME}/.pi/agent/npm/node_modules/pi-subagents`);
const scratch = mkdtempSync(join(tmpdir(), 'pi-tool-plan-test-'));
cpSync(join(packageDir, 'src'), join(scratch, 'src'), { recursive: true });
try {
  if (process.env.TEST_UNPATCHED !== '1') {
    execFileSync('patch', ['--batch', '--forward', '--fuzz=0', '-p1', '-i', resolve(import.meta.dirname, 'tool-availability.patch')], { cwd: scratch });
  }
  const file = join(scratch, 'src/runs/shared/child-tool-plan.ts');
  let source = stripTypeScriptTypes(readFileSync(file, 'utf8'));
  const data = (text) => `data:text/javascript,${encodeURIComponent(text)}`;
  const replacements = {
    './mcp-direct-tool-allowlist.ts': data('export const resolveMcpDirectToolResolution = () => ({selections: [], unresolvedSelectors: []}); export const formatUnresolvedMcpDirectToolSelectors = () => "unexpected MCP selection";'),
    '../../shared/types.ts': data(`export const TEMP_ROOT_DIR = ${JSON.stringify(scratch)};`),
    '../../shared/model-info.ts': data('export const THINKING_LEVELS = ["off", "low", "medium", "high"];'),
    '../../shared/utils.ts': data(`export const getAgentDir = () => ${JSON.stringify(scratch)};`),
    './capability-ceiling.ts': pathToFileURL(join(scratch, 'src/runs/shared/capability-ceiling.ts')).href,
  };
  for (const [from, to] of Object.entries(replacements)) source = source.replace(JSON.stringify(from), JSON.stringify(to));
  source = source.replaceAll('import.meta.url', JSON.stringify(pathToFileURL(file).href));
  const { getHostBuiltinToolNames, resolvePiLaunchToolPlan } = await import(data(source));
  const host = getHostBuiltinToolNames({ getAllTools: () => [
    { name: 'read', sourceInfo: { source: 'builtin' } },
    { name: 'bash', sourceInfo: { source: 'npm:pi-colours' } },
    { name: 'web_search', sourceInfo: { source: 'npm:pi-web-access' } },
  ] });
  test('parent colours wrapper does not hide child bash', () => {
    const plan = resolvePiLaunchToolPlan({ agentName: 'scout', tools: ['read', 'bash'], hostAvailableBuiltins: host, extensions: [] });
    assert.deepEqual(plan.effectiveToolAllowlist, ['read', 'bash']);
    assert.equal(plan.disableAmbientExtensions, true);
  });
  const webTools = ['web_search', 'fetch_content', 'get_search_content', 'source_check'];
  test('web tools remain strict requirements, including child-only providers', () => {
    const plan = resolvePiLaunchToolPlan({ agentName: 'researcher', tools: ['read', ...webTools], hostAvailableBuiltins: ['read'], extensions: ['/test/pi-web-access/index.ts'] });
    assert.deepEqual(plan.requiredChildTools, ['read', ...webTools]);
    assert.deepEqual(plan.unavailableHostBuiltins, []);
    assert.equal(plan.disableAmbientExtensions, true);
    assert.deepEqual(plan.configuredExtensions, ['/test/pi-web-access/index.ts']);
    assert.ok(plan.extensionArgs.includes('/test/pi-web-access/index.ts'));
    assert.ok(!plan.extensionArgs.some(p => p.includes('pi-colours')));
  });
  test('a genuinely absent repository tool still blocks a scout', () => {
    assert.throws(() => resolvePiLaunchToolPlan({ agentName: 'scout', tools: ['read', 'bash'], hostAvailableBuiltins: ['read'] }), /required repository tools \[bash\]/);
  });
  test('tool ceilings and explicit exclusions still restrict tools', () => {
    const plan = resolvePiLaunchToolPlan({ tools: ['read', 'bash', ...webTools], hostAvailableBuiltins: host, excludeTools: ['web_search'], capabilityCeiling: { version: 1, allowedTools: ['read', 'web_search'], denyExtensions: true, sources: ['test'] }, extensions: ['/test/pi-web-access/index.ts'] });
    assert.deepEqual(plan.effectiveToolAllowlist, ['read']);
    assert.deepEqual(plan.requiredChildTools, ['read']);
    assert.deepEqual(plan.configuredExtensions, []);
  });
} finally {
  // Tests below are synchronous and their module code is already loaded.
  process.once('exit', () => rmSync(scratch, { recursive: true, force: true }));
}
