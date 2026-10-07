#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { loadPlaywright } from '../skill/scripts/_pw.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));
const skill = path.join(root, 'skill');
const viewport = { width: 480, height: 270 };
const hash = (buffer) => createHash('sha256').update(buffer).digest('hex');
const systems = JSON.parse(readFileSync(path.join(skill, 'systems.json'), 'utf8'));
const missing = systems.filter((system) => !existsSync(path.join(skill, system.file)));
if (missing.length) {
  for (const system of missing) console.error(`FAIL render: ${system.file}: required registered template is missing`);
  process.exit(1);
}
let playwright;
try {
  playwright = await loadPlaywright();
} catch (error) {
  if (error.code === 'PLAYWRIGHT_MISSING') {
    console.log('SKIP render checks: Playwright is unavailable. Set PW_DIR to a directory containing node_modules/playwright.');
    process.exit(0);
  }
  console.error(`FAIL loading Playwright: ${error.message}`);
  process.exit(1);
}

const work = mkdtempSync(path.join(tmpdir(), 'motion-render-'));
let browser;
let failures = 0;

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: root,
    encoding: 'utf8',
    timeout: 180_000,
    stdio: ['ignore', 'pipe', 'pipe'],
    env: process.env,
  });
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${path.basename(command)} failed: ${result.stderr || result.stdout || `exit ${result.status}`}`);
  return result.stdout;
}

function available(command) {
  const result = spawnSync(command, ['-version'], {
    encoding: 'utf8', timeout: 10_000, stdio: ['ignore', 'pipe', 'pipe'],
  });
  if (result.error?.code === 'ENOENT') return false;
  assert.ifError(result.error);
  assert.equal(result.status, 0, `${command} is present but its version check failed`);
  return true;
}

async function open(file, params, reducedMotion = 'no-preference', { noWebGL = false, ridges = false } = {}) {
  const context = await browser.newContext({ viewport, deviceScaleFactor: 1, reducedMotion, offline: true });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => {
    if (message.type() === 'error') errors.push(message.text());
  });
  page.on('request', (request) => {
    if (/^https?:/.test(request.url())) errors.push(`external request: ${request.url()}`);
  });
  await page.addInitScript(({ noWebGL, ridges }) => {
    if (noWebGL) {
      const getContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function (kind, ...args) {
        if (/webgl|experimental-webgl/.test(kind)) return null;
        return getContext.call(this, kind, ...args);
      };
    }
    if (ridges) {
      window.__ridgeFills = [];
      window.__ridgeStrokes = 0;
      const prototype = CanvasRenderingContext2D.prototype;
      const fill = prototype.fill, stroke = prototype.stroke;
      prototype.stroke = function (...args) {
        if (this.canvas.id === 'c') window.__ridgeStrokes++;
        return stroke.apply(this, args);
      };
      prototype.fill = function (...args) {
        if (this.canvas.id !== 'c') return fill.apply(this, args);
        // Put known farther ink below the crest. Some seeded frames have no
        // natural overlaps, so they cannot prove occlusion without this probe.
        this.save();
        this.globalAlpha = 1; this.fillStyle = '#102030';
        this.fillRect(this.canvas.width * 0.2, this.canvas.height * 0.96, this.canvas.width * 0.6, 3);
        this.restore();
        const before = this.getImageData(0, 0, this.canvas.width, this.canvas.height).data;
        fill.apply(this, args);
        const after = this.getImageData(0, 0, this.canvas.width, this.canvas.height).data;
        const ground = [0xe4, 0xd6, 0xbd];
        let erased = 0;
        for (let i = 0; i < before.length; i += 4) {
          if (ground.every((value, channel) => after[i + channel] === value) &&
              ground.some((value, channel) => Math.abs(before[i + channel] - value) >= 8)) erased++;
        }
        const bottom = (this.canvas.width * (this.canvas.height - 1) + Math.floor(this.canvas.width / 2)) * 4;
        window.__ridgeFills.push({ alpha: this.globalAlpha, color: this.fillStyle,
          strokes: window.__ridgeStrokes, erased,
          reachesBottom: ground.every((value, channel) => after[bottom + channel] === value) });
      };
    }
    window.__motionRafCount = 0;
    window.__motionNativeRaf = window.requestAnimationFrame.bind(window);
    window.requestAnimationFrame = (callback) => {
      window.__motionRafCount += 1;
      return window.__motionNativeRaf(callback);
    };
  }, { noWebGL, ridges });
  const url = pathToFileURL(file);
  for (const [key, value] of Object.entries(params)) url.searchParams.set(key, String(value));
  await page.goto(url.href, { waitUntil: 'load' });
  await page.locator('canvas').waitFor({ state: 'visible' });
  assert.equal(await page.locator('canvas').count(), 1, 'template must expose one canvas');
  const size = await page.locator('canvas').boundingBox();
  assert.ok(size && size.x === 0 && size.y === 0 && size.width === viewport.width && size.height === viewport.height,
    'canvas must fill the viewport');
  return { page, context, errors };
}

async function pixels(page, width = viewport.width, height = viewport.height) {
  const encoded = await page.evaluate(([width, height]) => {
    const copy = document.createElement('canvas');
    copy.width = width; copy.height = height;
    const context = copy.getContext('2d');
    context.imageSmoothingQuality = 'high';
    context.drawImage(document.querySelector('canvas'), 0, 0, width, height);
    const data = context.getImageData(0, 0, width, height).data;
    let bytes = '';
    for (let i = 0; i < data.length; i += 8192) bytes += String.fromCharCode(...data.subarray(i, i + 8192));
    return btoa(bytes);
  }, [width, height]);
  return Buffer.from(encoded, 'base64');
}

function pixelDifference(a, b) {
  assert.equal(a.length, b.length, 'pixel samples must have the same size');
  let changed = 0, total = 0;
  for (let i = 0; i < a.length; i += 4) {
    const delta = (Math.abs(a[i] - b[i]) + Math.abs(a[i + 1] - b[i + 1]) + Math.abs(a[i + 2] - b[i + 2])) / 3;
    total += delta;
    if (delta >= 16) changed++;
  }
  return { fraction: changed / (a.length / 4), mean: total / (a.length / 4) };
}

async function snapshot(file, params, options = {}, sample = false) {
  const { page, context, errors } = await open(file, params, 'no-preference', options);
  try {
    const png = await page.screenshot();
    assert.deepEqual(errors, [], 'page or console errors');
    assert.equal(await page.evaluate(() => window.__motionRafCount), 0, 'p must render a still without scheduling playback');
    return {
      hash: hash(png),
      pixels: sample ? await pixels(page) : null,
      thumbnail: sample ? await pixels(page, 48, 27) : null,
    };
  } finally {
    await context.close();
  }
}

async function checkLorenzBounds(file) {
  let minAspect = Infinity, maxAspect = 0, minArea = Infinity;
  for (let seed = 1; seed <= 12; seed++) {
    const { page, context, errors } = await open(file, { seed, p: 0 });
    try {
      // Include the default frame, contact-sheet phase, and the whole camera orbit.
      for (const phase of [0, 0.125, 0.25, 0.33, 0.375, 0.5, 0.625, 0.75, 0.875]) {
        await page.evaluate((phase) => window.renderFrame(phase * 1000, 1000), phase);
        const data = await pixels(page);
        let left = viewport.width, right = -1, top = viewport.height, bottom = -1;
        for (let y = 0; y < viewport.height; y++) {
          for (let x = 0; x < viewport.width; x++) {
            const i = (y * viewport.width + x) * 4;
            // Ignore faint antialiasing against the unpainted top-left background.
            if (Math.max(Math.abs(data[i] - data[0]), Math.abs(data[i + 1] - data[1]), Math.abs(data[i + 2] - data[2])) < 16) continue;
            left = Math.min(left, x); right = Math.max(right, x);
            top = Math.min(top, y); bottom = Math.max(bottom, y);
          }
        }
        const label = `Lorenz seed ${seed}, phase ${phase}`;
        assert.ok(right >= left && bottom >= top, `${label}: no visible painted bounds`);
        const width = right - left + 1, height = bottom - top + 1;
        const aspect = width / height, area = width * height / (viewport.width * viewport.height);
        assert.ok(aspect >= 0.6 && aspect <= 2.8,
          `${label}: painted bounds ${width}x${height} are a sliver (aspect ${aspect.toFixed(3)}; need 0.6-2.8)`);
        assert.ok(area >= 0.18,
          `${label}: painted bounds cover ${(area * 100).toFixed(2)}% of the frame; need >=18%`);
        minAspect = Math.min(minAspect, aspect); maxAspect = Math.max(maxAspect, aspect);
        minArea = Math.min(minArea, area);
      }
      assert.deepEqual(errors, [], `Lorenz seed ${seed}: page or console errors`);
    } finally {
      await context.close();
    }
  }
  console.log(`PASS Lorenz painted bounds: seeds 1-12, 9 phases, aspect ${minAspect.toFixed(2)}-${maxAspect.toFixed(2)}, minimum area ${(minArea * 100).toFixed(1)}%`);
}

async function checkTemplate(file, slug, options = {}) {
  if (slug === 'lorenz') await checkLorenzBounds(file);
  const first = await snapshot(file, { seed: 1, p: 0.33 }, options, true);
  const repeated = await snapshot(file, { seed: 1, p: 0.33 }, options);
  const other = await snapshot(file, { seed: 2, p: 0.33 }, options, true);
  const defaultSeed = await snapshot(file, { p: 0.33 }, options);
  assert.equal(first.hash, repeated.hash, 'seed 1 must produce identical PNG bytes on independent loads');
  // Ignore tiny channel changes: at least 1% of all pixels must differ by 16/255
  // mean RGB levels. Full resolution retains small marks in sparse line art.
  const difference = pixelDifference(first.pixels, other.pixels);
  assert.ok(difference.fraction >= 0.01,
    `seeds 1 and 2 must visibly differ: ${(difference.fraction * 100).toFixed(2)}% of pixels changed by >=16 RGB levels; need >=1%`);
  if (slug === 'lorenz' || slug === 'aizawa') {
    // These dense trajectories must also change their overall composition;
    // averaging into a thumbnail prevents shuffled fine lines from passing.
    const shape = pixelDifference(first.thumbnail, other.thumbnail);
    assert.ok(shape.fraction >= 0.05,
      `seeded attractor composition must change: ${(shape.fraction * 100).toFixed(2)}% of thumbnail pixels changed by >=16 RGB levels; need >=5%`);
  }
  assert.equal(first.hash, defaultSeed.hash, 'omitting seed must default to seed 1');

  const still = await open(file, { seed: 1, p: 0.33 }, 'no-preference', options);
  try {
    assert.equal(await still.page.evaluate(() => typeof window.renderFrame), 'function', 'window.renderFrame must be callable');
    await still.page.evaluate(() => window.renderFrame(33, 100));
    assert.equal(hash(await still.page.screenshot()), first.hash, 'renderFrame must match the corresponding p still');
    await still.page.evaluate(() => window.renderFrame(73, 100));
    const moved = hash(await still.page.screenshot());
    assert.notEqual(moved, first.hash, 'different loop phases must move the picture');
    await still.page.evaluate(() => window.renderFrame(33, 100));
    assert.equal(hash(await still.page.screenshot()), first.hash, 'renderFrame must work out of order without accumulated state');
    await still.page.evaluate(() => window.renderFrame(0, 100));
    const start = hash(await still.page.screenshot());
    await still.page.evaluate(() => window.renderFrame(100, 100));
    assert.equal(hash(await still.page.screenshot()), start, 'loop phases 0 and 1 must match exactly');
    assert.deepEqual(still.errors, [], 'renderFrame page or console errors');
  } finally {
    await still.context.close();
  }

  const reduced = await open(file, { seed: 1 }, 'reduce', options);
  try {
    // Observe browser frames using the original RAF, without counting the test itself.
    await reduced.page.evaluate(() => new Promise((resolve) => {
      let frames = 0;
      const observe = () => {
        frames += 1;
        if (frames === 4) resolve();
        else window.__motionNativeRaf(observe);
      };
      window.__motionNativeRaf(observe);
    }));
    assert.equal(await reduced.page.evaluate(() => window.__motionRafCount), 0,
      'reduced motion must never schedule requestAnimationFrame');
    const drawn = await reduced.page.evaluate(() => {
      const source = document.querySelector('canvas');
      const copy = document.createElement('canvas');
      copy.width = source.width;
      copy.height = source.height;
      const context = copy.getContext('2d');
      context.drawImage(source, 0, 0);
      const pixels = context.getImageData(0, 0, copy.width, copy.height).data;
      let visible = false;
      let varied = false;
      for (let i = 0; i < pixels.length; i += 4) {
        if (pixels[i + 3] !== 0) visible = true;
        if (pixels[i] !== pixels[0] || pixels[i + 1] !== pixels[1] || pixels[i + 2] !== pixels[2] || pixels[i + 3] !== pixels[3]) varied = true;
      }
      return visible && varied;
    });
    assert.ok(drawn, 'reduced motion must draw a visible, non-blank canvas');
    assert.deepEqual(reduced.errors, [], 'reduced-motion page or console errors');
  } finally {
    await reduced.context.close();
  }
  console.log(`PASS render: ${slug} (seed determinism, ${(difference.fraction * 100).toFixed(1)}% visible seed variation, stills, loop seam, reduced motion)`);
}

try {
  browser = await playwright.chromium.launch({ headless: true });
  for (const system of systems) {
    const file = path.join(skill, system.file);
    try {
      await checkTemplate(file, system.slug);
    } catch (error) {
      failures += 1;
      console.error(`FAIL render: ${system.slug}: ${error.message}`);
    }
  }

  try {
    const ridge = await open(path.join(skill, 'templates', 'noise-ridgelines.html'),
      { seed: 1, p: 0.33, bg: 'e4d6bd' }, 'no-preference', { ridges: true });
    try {
      const fills = await ridge.page.evaluate(() => window.__ridgeFills);
      assert.ok(fills.length >= 2, 'ridgelines must fill the ground below each ridge to hide farther lines');
      assert.ok(fills.every(fill => fill.alpha === 1 && fill.color === '#e4d6bd'),
        'ridge occlusion must use the opaque ground color, including palette overrides');
      assert.equal(fills.length, await ridge.page.evaluate(() => window.__ridgeStrokes), 'each ridge must get a ground mask');
      assert.ok(fills.every((fill, index) => fill.strokes === index && fill.reachesBottom),
        'each ground mask must cover down to the bottom before stroking its crest');
      const erased = fills.reduce((total, fill) => total + fill.erased, 0);
      assert.ok(erased > 20, `near ridges must hide farther ink; only ${erased} pixels erased`);
      assert.deepEqual(ridge.errors, [], 'ridge occlusion page or console errors');
      console.log(`PASS ridgelines: opaque ground masks hide ${erased} farther ink probe pixels`);
    } finally { await ridge.context.close(); }
  } catch (error) {
    failures++;
    console.error(`FAIL ridgeline occlusion: ${error.message}`);
  }

  try {
    const file = path.join(skill, 'templates', 'raymarching.html');
    for (const params of [{ seed: 1, p: 0.33 }, { seed: 2, p: 0.73, bg: '123', ink: 'ddd', accent: 'ca8742' }]) {
      const gpu = await open(file, params);
      const cpu = await open(file, params, 'no-preference', { noWebGL: true });
      try {
        assert.ok(await gpu.page.evaluate(() => !!document.querySelector('canvas').getContext('webgl')),
          'WebGL is required to verify that the CPU fallback renders the same scene');
        assert.ok(await cpu.page.evaluate(() => !!document.querySelector('canvas').getContext('2d')),
          'forced no-WebGL check must use the CPU canvas');
        const difference = pixelDifference(await pixels(gpu.page, 160, 90), await pixels(cpu.page, 160, 90));
        assert.ok(difference.mean < 4,
          `CPU fallback must match the raymarched scene: mean RGB error ${difference.mean.toFixed(2)} must be <4/255`);
        assert.ok(await cpu.page.evaluate(() => {
          const canvas = document.querySelector('canvas');
          return canvas.width * canvas.height <= 57600;
        }), 'CPU fallback must use a reduced pixel budget');
        const before = hash(await cpu.page.screenshot());
        await cpu.page.setViewportSize({ width: 640, height: 400 });
        await cpu.page.waitForFunction(() => document.querySelector('canvas').height !== 180);
        await cpu.page.setViewportSize(viewport);
        // Wait for resize delivery before checking the synchronous render hook.
        await cpu.page.waitForFunction(() => document.querySelector('canvas').width === 320);
        await cpu.page.evaluate(phase => window.renderFrame(Math.round(phase * 100), 100), params.p);
        assert.equal(hash(await cpu.page.screenshot()), before, 'CPU resize must preserve the seeded phase');
        assert.deepEqual(cpu.errors, [], 'CPU fallback page or console errors');
        assert.deepEqual(gpu.errors, [], 'WebGL reference page or console errors');
        console.log(`PASS raymarching scene: seed ${params.seed}, phase ${params.p}, CPU mean RGB error ${difference.mean.toFixed(2)}/255`);
      } finally { await gpu.context.close(); await cpu.context.close(); }
    }
    await checkTemplate(file, 'raymarching CPU fallback', { noWebGL: true });
    console.log('PASS raymarching: CPU and WebGL render the same scene');
  } catch (error) {
    failures++;
    console.error(`FAIL raymarching fallback: ${error.message}`);
  }

  const flow = path.join(skill, 'templates', 'flow-field.html');
  const sheet = path.join(work, 'contact');
  run(process.execPath, [path.join(skill, 'scripts', 'contact-sheet.mjs'), flow, sheet,
    '--width', '320', '--height', '180', '--cols', '4']);
  assert.equal(readdirSync(sheet).filter((name) => /^seed-\d{2}\.png$/.test(name)).length, 12,
    'contact sheet must include exactly 12 seed PNGs');
  for (let seed = 1; seed <= 12; seed += 1) {
    assert.ok(existsSync(path.join(sheet, `seed-${String(seed).padStart(2, '0')}.png`)), `contact seed ${seed} is missing`);
  }
  const contactPage = await browser.newPage();
  await contactPage.goto(pathToFileURL(path.join(sheet, 'sheet.html')).href);
  assert.equal(await contactPage.locator('img').count(), 12, 'contact sheet must display 12 image cells');
  assert.ok(await contactPage.locator('img').evaluateAll((images) => images.every((img) => img.complete && img.naturalWidth > 0)),
    'all 12 contact sheet images must load');
  await contactPage.close();
  const sheetPng = readFileSync(path.join(sheet, 'sheet.png'));
  assert.equal(sheetPng.subarray(1, 4).toString(), 'PNG', 'sheet.png must be a PNG image');
  console.log('PASS contact sheet: 12 seeds, 12 loaded cells, sheet.html and sheet.png');

  if (!available('ffmpeg')) {
    console.log('SKIP MP4 export: ffmpeg is not on PATH');
  } else {
    assert.ok(available('ffprobe'), 'ffmpeg is installed but ffprobe is missing; install ffprobe to validate MP4 output');
    const movie = path.join(work, 'flow-field.mp4');
    run('bash', [path.join(skill, 'scripts', 'export-mp4.sh'), flow, movie,
      '--fps', '6', '--duration', '1', '--width', '320', '--height', '180', '--seed', '1']);
    const probe = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
      '-show_entries', 'stream=codec_name,width,height,nb_frames:format=duration,format_name', '-of', 'json', movie]));
    assert.equal(probe.streams.length, 1, 'MP4 must contain a video stream');
    assert.equal(probe.streams[0].width, 320, 'MP4 width');
    assert.equal(probe.streams[0].height, 180, 'MP4 height');
    assert.equal(Number(probe.streams[0].nb_frames), 6, 'MP4 must contain six frames');
    assert.ok(Number(probe.format.duration) > 0, 'MP4 duration must be positive');
    assert.ok(probe.format.format_name.split(',').includes('mp4'), 'export must use an MP4 container');
    console.log('PASS MP4 export: valid 320x180 video, 6 frames');
  }
} catch (error) {
  failures += 1;
  console.error(`FAIL render checks: ${error.message}`);
} finally {
  if (browser) await browser.close();
  rmSync(work, { recursive: true, force: true });
}
console.log(`${failures ? 'FAIL' : 'PASS'} render checks: ${failures} failures`);
process.exitCode = failures ? 1 : 0;
