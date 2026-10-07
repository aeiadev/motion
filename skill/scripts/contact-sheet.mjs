#!/usr/bin/env node
// Render seeds 1..12 at a fixed loop phase, then make a portable visual index.
import { mkdir, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { loadPlaywright, reportCliError } from './_pw.mjs';

const usage = 'Usage: node contact-sheet.mjs <template.html> <output-dir> [--width 320] [--height 180] [--cols 4] [--phase 0.33]';

function parseArgs(args) {
  if (args.length < 2 || args[0].startsWith('--') || args[1].startsWith('--')) throw new Error(usage);
  const options = { width: 320, height: 180, cols: 4, phase: 0.33 };
  for (let i = 2; i < args.length; i += 2) {
    const name = args[i].slice(2);
    if (!args[i].startsWith('--') || !Object.hasOwn(options, name) || args[i + 1] === undefined || args[i + 1].trim() === '') {
      throw new Error(`Unknown option or missing value: ${args[i]}. ${usage}`);
    }
    options[name] = Number(args[i + 1]);
  }
  for (const name of ['width', 'height', 'cols']) {
    if (!Number.isSafeInteger(options[name]) || options[name] < 1) throw new Error(`--${name} must be a positive integer.`);
  }
  if (options.width > 8192 || options.height > 8192) throw new Error('--width and --height must be at most 8192.');
  if (options.cols > 12) throw new Error('--cols must be between 1 and 12.');
  if (!Number.isFinite(options.phase) || options.phase < 0 || options.phase > 1) throw new Error('--phase must be between 0 and 1.');
  return { input: path.resolve(args[0]), output: path.resolve(args[1]), ...options };
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
    const cells = [];
    for (let seed = 1; seed <= 12; seed++) {
      errors.length = 0;
      const url = pathToFileURL(options.input);
      url.searchParams.set('seed', String(seed));
      url.searchParams.set('p', String(options.phase));
      await page.goto(url.href, { waitUntil: 'load' });
      const canvas = page.locator('canvas').first();
      if (await canvas.count() === 0) throw new Error(`Seed ${seed}: no canvas found.`);
      const png = await canvas.screenshot({ type: 'png' });
      if (errors.length) throw new Error(`Seed ${seed}: ${errors.join('; ')}`);
      await writeFile(path.join(options.output, `seed-${String(seed).padStart(2, '0')}.png`), png);
      cells.push(`<figure data-seed="${seed}"><img width="${options.width}" height="${options.height}" alt="Seed ${seed}" src="data:image/png;base64,${png.toString('base64')}"><figcaption>Seed ${seed}</figcaption></figure>`);
    }
    const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Motion: seeds 1 to 12</title>
<style>*{box-sizing:border-box}body{margin:0;padding:8px;background:#181818;color:#fff;font:14px monospace}main{display:grid;grid-template-columns:repeat(${options.cols},${options.width}px);gap:8px;width:max-content}figure{margin:0}img{display:block}figcaption{padding:7px 0}</style>
</head><body><main aria-label="Seeds 1 to 12">${cells.join('\n')}</main></body></html>\n`;
    await writeFile(path.join(options.output, 'sheet.html'), html);
    const sheet = await browser.newPage({ viewport: { width: options.cols * (options.width + 8) + 8, height: 600 }, deviceScaleFactor: 1 });
    await sheet.setContent(html, { waitUntil: 'load' });
    await sheet.evaluate(() => Promise.all(Array.from(document.images, image => image.decode())));
    await sheet.screenshot({ path: path.join(options.output, 'sheet.png'), fullPage: true });
    console.log(`Wrote 12 seed images, sheet.html, and sheet.png to ${options.output}`);
  } finally {
    await browser.close();
  }
}

main().catch(reportCliError);
