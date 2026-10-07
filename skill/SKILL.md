---
name: motion
description: Turn a visual brief into a repeating animation drawn in HTML. Explore 23 templates through seed previews, refine a chosen composition, and deliver a browser artwork or video. Suitable for animated backgrounds, procedural graphics, and visual identities.
---

# Motion

Build each piece as one HTML file with inline CSS and JavaScript, no libraries,
and no network. Use canvas 2D by default; raymarching may use an inline WebGL
shader. Follow [TEMPLATE-CONTRACT.md](references/TEMPLATE-CONTRACT.md).

## Method

1. **Set the destination.** Record where the artwork will appear, its dimensions,
   colours, and cycle duration. Note any area that must stay clear for content.
   Resolve missing details only when they affect the next design choice.
2. **Choose a structure.** Browse the families in [systems.md](references/systems.md).
   Thread bundles (`thread-bundles`) suits sweeping lines; Ring stack (`ring-stack`)
   and Looped strip (`looped-strip`) offer objects with depth; Stamp grid
   (`stamp-grid`) starts from repeated marks. Explain the choice and identify the
   controls worth adjusting. Copy the matching `file` from `systems.json`; each
   of its 23 entries has a runnable template.
3. **Compare compositions.** Render a sheet for seeds 1 through 12 using identical
   viewport and phase settings. Select an image for its framing and distribution
   of detail, discarding blank or collapsed results. Save the seed with the brief.
4. **Revise with a clear question.** Keep the chosen seed while testing one change:
   a cue from an image, a surface treatment, a composition constraint, or a feature
   from another system. Compare the revised image and playback with the previous
   result. Accept or revert the change before starting another; preview a new
   sheet if the seed itself needs to change.
5. **Prepare delivery.** Save the finished HTML with its seed and settings. For a
   website, include a poster and check the text against the moving background.
   For video, inspect the MP4 through the point where playback repeats.

## Brief template

```text
Use: <site hero | identity | clip>
Output: one self-contained HTML file, inline canvas JavaScript, no network
System: <slug, mechanism, main parameters>
Palette: --bg <color>, --ink <color>, --accent <color>
Loop: <seconds>, seamless
Viewport: <width> x <height>
Limit: <quiet region, density, line weight, or another constraint>
First steer: <one reference image, material, limit, or second system>
```

## Work from the installed skill

On either Claude Code or Codex CLI, find the path of this loaded `SKILL.md` in
the host's skill listing. Its containing directory is the skill root. Set the
shell variable `SKILL_DIR` to that actual absolute directory before running the
commands below. Resolve `templates/`, `scripts/`, `references/`, and `systems.json`
relative to it, including paths mentioned in references. Do not assume that the
project's working directory is the skill root or that a host sets a path variable.
If the path is not shown, use the host's skill listing to locate Motion first.

The usual user installs are `~/.claude/skills/motion` for Claude Code and
`~/.agents/skills/motion` for Codex. Repository installs and custom locations can
differ, so use the directory of the file actually loaded. In the example below,
replace the placeholder with that directory. Keep generated work in the current
project and keep paths quoted so installations with spaces work.

```bash
SKILL_DIR="/path/to/motion" # Replace with the directory containing this SKILL.md.
mkdir -p out
cp "$SKILL_DIR/templates/flow-field.html" out/piece.html
node "$SKILL_DIR/scripts/contact-sheet.mjs" out/piece.html out/seeds
```

Open `out/seeds/sheet.png` or `sheet.html` to compare the 12 labeled cells. The
default phase is 0.33; `--width`, `--height`, `--cols`, and `--phase` are available.
Open the piece with `?seed=7` to play seed 7, or `?seed=7&p=0.33` for a still.

```bash
bash "$SKILL_DIR/scripts/export-mp4.sh" out/piece.html out/piece.mp4 \
  --seed 7 --duration 4 --fps 30 --width 1280 --height 720
```

Export needs Playwright with Chromium and ffmpeg on PATH. Set `PW_DIR` to a
directory containing `node_modules/playwright` when a normal import cannot find
it. Neither tool is needed to open the HTML. Scripts fail with a dependency hint
and exit 2 when required tools are missing.

## Implementation rules

- Parse `?seed=N`, default 1, and use mulberry32 for every random choice. Draw the
  same seed, phase, viewport, and palette identically on repeat loads.
- Compute frames from seed and phase without relying on previous draws. Map the
  phase onto a circle with sine and cosine for periodic motion. Reset simulations
  deterministically or precompute their loop; do not accumulate hidden state.
- Expose `window.renderFrame(i, total)`. Render phase `i / total`, wrap at 1, and
  stop live playback for export. `?p=0..1` draws one still, with 1 matching 0.
- Respect reduced motion: draw a finished still and start no animation loop.
  Cap device pixel ratio at 2, skip drawing while hidden, and support Space to
  freeze playback. Keep the resting image complete and readable.
- Treat palette, duration, viewport, and seed as inputs. The shipped templates
  accept `t` for seconds and `bg`, `ink`, `accent` for hex colors in the query.
- Keep all assets inline. No external scripts, fonts, URLs, imports, or requests.

## Review before delivery

Check repeat-seed equality, seed variation, phase stills, the last-to-first seam,
reduced-motion stills, viewport resizing, and the browser console. Inspect both
texture and pacing in playback, not only a single frame. Use
[web-hero.md](references/web-hero.md) for hero integration and
[rebuild-from-reference.md](references/rebuild-from-reference.md) for a reference.

The repository's static and browser tests check the contract. When adding a
template to the repository, run them and the fresh-user install check. A piece
intended for a particular site also needs a visual check in that site's layout.
