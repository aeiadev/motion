#!/usr/bin/env node
// Step the deterministic export hook and write numbered PNG frames.
import { mkdir, stat } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { loadPlaywright, reportCliError } from './_pw.mjs';

const usage = 'Usage: node render-frames.mjs <template.html> <output-dir> [--fps 30] [--duration 4] [--width 1280] [--height 720] [--seed 1]';

function parseArgs(args) {
  if (args.length < 2 || args[0].startsWith('--') || args[1].startsWith('--')) throw new Error(usage);
  const options = { fps: 30, duration: 4, width: 1280, height: 720, seed: 1 };
  for (let i = 2; i < args.length; i += 2) {
    const name = args[i].slice(2);
    if (!args[i].startsWith('--') || !Object.hasOwn(options, name) || args[i + 1] === undefined || args[i + 1].trim() === '') {
      throw new Error(`Unknown option or missing value: ${args[i]}. ${usage}`);
    }
    options[name] = Number(args[i + 1]);
  }
  for (const name of ['fps', 'width', 'height']) {
    if (!Number.isSafeInteger(options[name]) || options[name] < 1) throw new Error(`--${name} must be a positive integer.`);
  }
  if (options.width > 8192 || options.height > 8192) throw new Error('--width and --height must be at most 8192.');
  if (!Number.isSafeInteger(options.seed) || options.seed < 0 || options.seed > 4294967295) throw new Error('--seed must be an integer from 0 to 4294967295.');
  if (!Number.isFinite(options.duration) || options.duration <= 0) throw new Error('--duration must be a positive number.');
  const total = Math.round(options.fps * options.duration);
  if (!Number.isSafeInteger(total) || total < 1 || total > 100000) throw new Error('--fps times --duration must round to between 1 and 100000 frames.');
  return { input: path.resolve(args[0]), output: path.resolve(args[1]), total, ...options };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (!(await stat(options.input)).isFile()) throw new Error('The template must be an HTML file.');
  const { chromium } = await loadPlaywright();
  const browser = await chromium.launch();
  try {
    await mkdir(options.output, { recursive: true });
    const page = await browser.newPage({ viewport: { width: options.width, height: options.height }, deviceScaleFactor: 1 });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
    const url = pathToFileURL(options.input);
    url.searchParams.set('seed', String(options.seed));
    url.searchParams.set('p', '0');
    await page.goto(url.href, { waitUntil: 'load' });
    const canvas = page.locator('canvas').first();
    if (await canvas.count() === 0) throw new Error('No canvas found.');
    if (!await page.evaluate(() => typeof window.renderFrame === 'function')) throw new Error('The template must define window.renderFrame(i, total).');
    for (let i = 0; i < options.total; i++) {
      await page.evaluate(([frame, total]) => window.renderFrame(frame, total), [i, options.total]);
      await canvas.screenshot({ type: 'png', path: path.join(options.output, `frame-${String(i).padStart(5, '0')}.png`) });
      if (errors.length) throw new Error(`Frame ${i}: ${errors.join('; ')}`);
    }
    console.log(`Wrote ${options.total} frames at ${options.fps} fps to ${options.output}`);
  } finally {
    await browser.close();
  }
}

main().catch(reportCliError);
