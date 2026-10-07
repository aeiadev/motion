# Template contract

Each system template is one self-contained HTML file. These rules describe the
interface used by the contact-sheet and frame-rendering scripts.
Registry, template, and script paths are relative to the directory containing
Motion's `SKILL.md`; use that loaded directory on either host.

## Document and assets

- Use an HTML doctype, inline CSS, and inline JavaScript only.
- Include exactly one visible canvas that fills the viewport without page margins
  or scrolling. Resize its backing store when the viewport changes.
- Include `<meta name="motion-system" content="<slug>">`, where the slug matches
  `systems.json` and the filename `templates/<slug>.html`.
- No external URLs, script `src`, JavaScript imports, fetch, XMLHttpRequest,
  WebSocket, external font links, or other network resources. Inline shaders and
  embedded data are allowed. Opening the file must need no server or library.
- Loading, rendering, and resizing must cause no page or console errors.

## Seed and phase

- Read the seed through `new URLSearchParams(location.search).get('seed')`.
  Default to 1 and fall back to 1 for an invalid value. The shipped templates
  normalize integer seeds to unsigned 32-bit values.
- Use a seeded `mulberry32` PRNG for every random decision. Do not use
  `Math.random()`, wall-clock time, or live input to define the picture.
- The same seed, phase, viewport, palette, browser, and pixel ratio must produce
  identical pixels on separate loads. Different seeds must produce different
  pictures. Cross-browser rasterization need not be byte-identical.
- `?p=0..1` draws a still at that loop phase and schedules no animation frames.
  Phase 1 is the same as phase 0. Without `p`, play the loop unless reduced motion
  is requested.
- Implement `window.renderFrame(i, total)`. It synchronously draws phase
  `i / total`, wrapped to `[0, 1)`, and stops live playback. `total` is a positive
  integer. The result must be independent of the order of earlier calls.
- Export frames `0` through `total - 1`; do not duplicate the endpoint. Frame 0
  must equal frame `total`, and the last-to-first change must be consistent with
  neighboring frames. Endpoint equality alone does not prove a smooth seam.

## Playback and accessibility

- With `matchMedia('(prefers-reduced-motion: reduce)').matches`, draw one complete,
  non-blank still and start no requestAnimationFrame loop. A resize may redraw
  that same phase. Respect preference changes during playback too.
- Use periodic parameters such as `cos(2 * Math.PI * p)` and
  `sin(2 * Math.PI * p)` for seamless loops. Reset or precompute simulation state
  so random-access rendering stays deterministic.
- Cap the backing-store pixel ratio at 2. Skip expensive drawing while hidden.
  The shipped templates also let Space pause and resume normal playback.
- Give standalone art an accessible canvas label. A decorative hero canvas
  should instead use `aria-hidden="true"` and leave content in semantic HTML.

## Shared optional controls

The shipped templates accept `?t=seconds` for playback duration and `bg`, `ink`,
and `accent` as 3- or 6-digit hex colors without `#`. CSS custom properties
`--bg`, `--ink`, and `--accent` define the default palette. Export duration is
controlled separately by the renderer's `--duration` and `--fps` arguments.

## Adding a template

All 23 registered systems ship templates. To adapt one, copy its registered file
and follow the catalogue's mechanism and loop recipe. To add a new system,
create its template and update `systems.json`, `systems.md`, the README, and the
expected registry in the static test together. Version 0.1.0 has 23 entries.

From the repository root, run:

```bash
node tests/static-check.mjs
node tests/render-check.mjs
bash tests/fresh-user.sh
bash tests/fresh-user-codex.sh
```

The static check checks source conventions, not arbitrary JavaScript semantics.
Browser tests verify deterministic pictures, varied seeds, frame controls,
reduced motion, the contact sheet, and MP4 export when its tools are available.
Review the sheet and playback by eye as well. Every registered template must
exist; missing files fail the static and browser checks.
