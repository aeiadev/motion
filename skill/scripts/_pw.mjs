// Playwright is optional. Point PW_DIR at a directory containing its node_modules.
import { createRequire } from 'node:module';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

export async function loadPlaywright() {
  if (process.env.PW_DIR) {
    const require = createRequire(path.join(path.resolve(process.env.PW_DIR), '__motion_loader__.cjs'));
    for (const name of ['playwright', 'playwright-core']) {
      try {
        const module = require(name);
        if (module.chromium) return module;
      } catch {}
    }
  }
  for (const name of ['playwright', 'playwright-core']) {
    try {
      const module = await import(name);
      if (module.chromium) return module;
      if (module.default?.chromium) return module.default;
    } catch {}
  }
  const error = new Error('Playwright was not found. Install playwright, or set PW_DIR to a directory whose node_modules contains playwright.');
  error.code = 'PLAYWRIGHT_MISSING';
  throw error;
}

export function reportCliError(error) {
  console.error(`ERROR: ${error.message || error}`);
  process.exitCode = 2;
}

// Running the loader directly is a useful installation check.
if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  try {
    await loadPlaywright();
    console.log('Playwright is available.');
  } catch (error) {
    reportCliError(error);
  }
}
