#!/usr/bin/env node
import assert from 'node:assert/strict';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const expectedSlugs = [
  'aizawa', 'lorenz', 'clifford',
  'flow-field', 'thread-bundles', 'noise-ridgelines', 'noise-rings',
  'flocking', 'slime-mould', 'differential-growth', 'reaction-diffusion',
  'ring-stack', 'looped-strip', 'soft-bodies', 'metaballs', 'raymarching', 'noise-papercut',
  'stamp-grid', 'voronoi', 'halftone', 'moire', 'harmonograph', 'guilloche',
];
let skillDir = fileURLToPath(new URL('../skill/', import.meta.url));
let failures = 0;
let present = 0;
let missing = 0;

function fail(message) {
  failures += 1;
  console.error(`FAIL ${message}`);
}

for (let i = 2; i < process.argv.length; i += 1) {
  const arg = process.argv[i];
  if (arg === '--skill-dir' && process.argv[i + 1]) skillDir = path.resolve(process.argv[++i]);
  else {
    console.error(`FAIL unknown or incomplete argument: ${arg}`);
    process.exit(2);
  }
}

try {
  const instructions = readFileSync(path.join(skillDir, 'SKILL.md'), 'utf8');
  const frontmatter = instructions.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/)?.[1];
  assert.ok(frontmatter, 'SKILL.md must start with YAML frontmatter');
  assert.match(frontmatter, /^name:[ \t]*motion[ \t]*$/m, 'SKILL.md must declare name: motion');
  assert.match(frontmatter, /^description:[ \t]*\S[^\r\n]*$/m, 'SKILL.md must declare a non-empty description');
  console.log('PASS skill metadata: name and description');
} catch (error) {
  fail(`skill metadata: ${error.message}`);
}

function checkReleaseWording(file, contents) {
  const obsolete = /pending|not\s+yet\s+coded|coming\s+soon/i.exec(contents);
  if (obsolete) {
    const line = contents.slice(0, obsolete.index).split('\n').length;
    fail(`${path.relative(skillDir, file)}:${line}: obsolete availability wording; all 23 templates ship in 0.1.0`);
  }
}

function checkSkillFiles(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) checkSkillFiles(file);
    else if (entry.isFile()) {
      const contents = readFileSync(file, 'utf8');
      checkReleaseWording(file, contents);
      if (contents.includes('CLAUDE_SKILL_DIR')) {
        fail(`${path.relative(skillDir, file)}: resolve bundled paths from the directory containing SKILL.md instead of a host-specific variable`);
      }
    }
  }
}

const root = fileURLToPath(new URL('../', import.meta.url));
function checkDocs(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    // The selected skill tree is checked separately, including installed copies.
    if (entry.name.startsWith('.') || ['node_modules', 'out'].includes(entry.name) || file === path.join(root, 'skill')) continue;
    if (entry.isDirectory()) checkDocs(file);
    else if (entry.isFile() && /\.md$/i.test(entry.name)) checkReleaseWording(file, readFileSync(file, 'utf8'));
  }
}
try {
  const before = failures;
  checkSkillFiles(skillDir);
  checkDocs(root);
  const changelog = readFileSync(path.join(root, 'CHANGELOG.md'), 'utf8');
  assert.doesNotMatch(changelog, /^##\s+.*\bunreleased\b/im, 'CHANGELOG.md must describe the shipped release');
  if (failures === before) console.log('PASS release docs and skill paths: current availability, portable paths');
} catch (error) {
  fail(`release docs and skill paths: ${error.message}`);
}

let systems;
try {
  systems = JSON.parse(readFileSync(path.join(skillDir, 'systems.json'), 'utf8'));
  assert.ok(Array.isArray(systems), 'systems.json must be an array');
  assert.equal(systems.length, 23, 'systems.json must contain exactly 23 systems');
  assert.equal(new Set(systems.map((system) => system.slug)).size, 23, 'system slugs must be unique');
  assert.deepEqual(systems.map((system) => system.slug), expectedSlugs, 'system slugs must follow the documented order');
  for (const system of systems) {
    assert.deepEqual(Object.keys(system).sort(), ['file', 'name', 'slug'], `${system.slug}: use exactly slug, name and file`);
    assert.ok(typeof system.name === 'string' && system.name.trim(), `${system.slug}: name must be a non-empty string`);
    assert.equal(system.file, `templates/${system.slug}.html`, `${system.slug}: unexpected template path`);
  }
  console.log('PASS registry: 23 unique systems in the documented order');
} catch (error) {
  fail(`registry: ${error.message}`);
  process.exit(1);
}

try {
  const readme = readFileSync(new URL('../README.md', import.meta.url), 'utf8');
  const rows = [...readme.matchAll(/^\|\s*\d+\s*\|\s*`([^`]+)`\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|/gm)];
  assert.deepEqual(rows.map(([, slug, name, availability]) => ({ slug, name, availability })),
    systems.map(({ slug, name }) => ({ slug, name, availability: 'Included' })),
    'README must list every registry system in order, with its exact name and Included template');
  console.log('PASS README: all 23 systems match the registry and include templates');
} catch (error) {
  fail(`README registry and availability: ${error.message}`);
}

function checkTemplate(file, slug) {
  const html = readFileSync(file, 'utf8');
  const reducedVariables = [...html.matchAll(/\b(?:const|let|var)\s+([\w$]+)\s*=\s*(?:window\.)?matchMedia\(\s*(['"])\(\s*prefers-reduced-motion\s*:\s*reduce\s*\)\2\s*\)/g)];
  const reducedGuard = reducedVariables.some(([, variable]) => {
    const escaped = variable.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp(`\\bif\\s*\\([^)]*\\b${escaped}\\b`).test(html);
  }) || /\bif\s*\([^)]*matchMedia\(\s*['"]\(\s*prefers-reduced-motion\s*:\s*reduce/.test(html);
  const checks = [
    [/<!doctype\s+html\s*>/i.test(html), 'include an HTML doctype'],
    [/<canvas\b/i.test(html), 'include a canvas'],
    [/<style\b[^>]*>[\s\S]*?<\/style>/i.test(html), 'keep CSS inline'],
    [/<script\b[^>]*>[\s\S]*?<\/script>/i.test(html), 'keep JavaScript inline'],
    [!/\b(?:https?|ftp):\/\/|(?:["'`(=]\s*)\/\//i.test(html), 'remove external URLs'],
    [!/<script\b[^>]*\bsrc\s*=/i.test(html), 'remove script src attributes'],
    [!/<(?:link|iframe|object|embed)\b/i.test(html), 'remove external document, font and stylesheet references'],
    [!/<\w+\b[^>]*\b(?:src|href|srcset|poster|data)\s*=\s*(?:["'](?!data:|#)[^"']+|(?=[^\s"'>])(?!data:|#)[^\s>]+)/i.test(html), 'remove external asset attributes'],
    [!/@import\b|url\(\s*["']?(?!data:)[^\s)]/i.test(html), 'remove external CSS resources'],
    [!/(?:^|[;\n{}])\s*import\s|\bimport\s*\(/m.test(html), 'remove JavaScript imports'],
    [!/\b(?:fetch\s*\(|XMLHttpRequest\b|WebSocket\s*\(|EventSource\s*\(|sendBeacon\s*\(|Worker\s*\()/i.test(html), 'remove network APIs'],
    [/\bURLSearchParams\b/.test(html) && /\.get\(\s*['"]seed['"]\s*\)/.test(html), 'parse the seed query parameter'],
    [/\bmulberry32\s*\(/.test(html), 'use the mulberry32 seeded PRNG'],
    [!/\bMath\.random\s*\(/.test(html), 'replace unseeded Math.random calls'],
    [/\.get\(\s*['"]p['"]\s*\)/.test(html), 'parse the still phase p query parameter'],
    [/\bwindow\.renderFrame\s*=/.test(html), 'expose window.renderFrame'],
    [reducedGuard, 'include a branch guarded by the reduced-motion media query result'],
    [/\brequestAnimationFrame\s*\(/.test(html), 'provide animated playback'],
  ];
  const metas = [...html.matchAll(/<meta\b[^>]*>/gi)];
  const systemMeta = metas.find(([tag]) => /\bname\s*=\s*["']motion-system["']/i.test(tag));
  const metaSlug = systemMeta?.[0].match(/\bcontent\s*=\s*["']([^"']*)["']/i)?.[1];
  checks.push([metaSlug === slug, `set motion-system metadata to ${slug}`]);
  for (const [ok, message] of checks) {
    if (!ok) fail(`${path.basename(file)}: ${message}`);
  }
  if (checks.every(([ok]) => ok)) console.log(`PASS template: ${slug}`);
}

for (const system of systems) {
  const file = path.join(skillDir, system.file);
  if (!existsSync(file)) {
    missing += 1;
    fail(`${system.file}: required registered template is missing`);
    continue;
  }
  present += 1;
  checkTemplate(file, system.slug);
}

const templateDir = path.join(skillDir, 'templates');
if (existsSync(templateDir)) {
  for (const file of readdirSync(templateDir)) {
    if (file.endsWith('.html') && !systems.some((system) => path.basename(system.file) === file)) {
      fail(`templates/${file}: template is not registered in systems.json`);
    }
  }
}
console.log(`${failures ? 'FAIL' : 'PASS'} static check: ${present} present, ${missing} missing, ${failures} failures`);
process.exitCode = failures ? 1 : 0;
