# Motion

Motion is an agent skill for Claude Code and OpenAI Codex CLI: a set of
instructions and templates the coding agent loads when you ask it for motion
work. It turns a short visual brief into a seeded, looping generative animation
in one self-contained HTML file. It is for developers and designers who need an
animated site background, a procedural graphic or a short clip. A seed fixes the
composition, so you can return to a chosen frame while you refine it.

Start with a template and preview twelve seeds together. Choose a composition,
then adjust one aspect of it between previews. Save the result as HTML for a
browser or export a video. Everything needed to draw the artwork lives in the
HTML; reduced-motion playback presents a still image.

Version 0.1.0 ships **23 working templates**, one for every system in the
catalogue. Each includes seeded composition, loop controls, palette overrides,
and a reduced-motion still frame.

## Install

For Codex, use **Codex CLI 0.156 or newer**. The installer uses
`~/.agents/skills`, which Codex 0.156 reads as its preferred user skill directory.
The `~/.codex/skills` location is deprecated in that version.

Clone the repository and run the installer:

```bash
git clone https://github.com/aeiadev/motion.git && cd motion
./install.sh
```

By default, the installer selects every host found on PATH (`claude` or `codex`)
or with an existing configuration directory (`${CLAUDE_HOME:-$HOME/.claude}` or
`${CODEX_HOME:-$HOME/.codex}`). It copies the same `skill/` tree to
`${CLAUDE_HOME:-$HOME/.claude}/skills/motion` for Claude Code and `$HOME/.agents/skills/motion`
for Codex. It never launches either host. If neither is present, choose a host
explicitly. Explicit selection also works before installing a host:

```bash
./install.sh --host claude
./install.sh --host codex
./install.sh --host both
```

Run the same command again to update. Each existing installation is preserved
in a unique `motion.backup.*` directory under
`${XDG_STATE_HOME:-$HOME/.local/state}/motion/backups` before replacement.
The installer rejects state paths inside the selected or standard skills roots.
Each saved copy has its path printed during reinstall. To restore a saved copy,
remove the current installation and move the backup directory to the original
`motion/` location.
Use `--dir` to choose a different skills parent directory for either host:

```bash
./install.sh --host codex --dir "$PWD/.agents/skills"
./install.sh --host claude --dir "$PWD/.claude/skills"
CLAUDE_HOME="$HOME/custom-claude" ./install.sh --host claude
```

With `--host both --dir ...`, one shared `motion/` directory is installed. Choose
a directory the selected hosts discover; arbitrary directories need host setup.
`--dir` takes precedence over `CLAUDE_HOME`. `CODEX_HOME` affects detection only;
Codex skills still default to `$HOME/.agents/skills`.

Restart your host session after installing. To remove the skill, repeat the
same host and directory options with `--uninstall`, for example
`./install.sh --host both --uninstall`. Backups are retained.

## Use with Codex

Install with `./install.sh --host codex`, restart Codex CLI, and ask:

```text
$motion Make a slow flow-field hero in ink on warm paper. Use a 12-second loop
at 1600 x 900. Compare seeds 1 to 12, then change one thing per round.
```

You can also select Motion through `/skills`. Give the brief in ordinary prose
after `$motion`. Codex discovers `~/.agents/skills/motion` and repository skills
under `.agents/skills/`. The content and scripts are shared
with Claude Code, which invokes the skill with `/motion`.

Both hosts resolve bundled files from the directory containing the loaded
`SKILL.md`. Codex does not expand Claude-specific path variables or enforce
Claude's `allowed-tools` metadata. Motion needs neither; shell and file access
follow the active host's permissions. Capture and export dependencies are the
same on both hosts.

## Use with Claude Code

Install with `./install.sh --host claude`, restart Claude Code, and ask:

```text
/motion Make a slow flow-field hero in ink on warm paper. Use a 12-second loop
at 1600 x 900. Keep a quiet region for the headline. Show seeds 1 to 12 before
choosing, then change one thing per round.
```

Or copy a template and open it directly in a browser:

```bash
SKILL_DIR="$PWD/skill" # From this repository; or use the installed skill directory.
mkdir -p out
cp "$SKILL_DIR/templates/flow-field.html" out/piece.html
```

Open `out/piece.html` with `?seed=7` to play seed 7. Add `&p=0.33` to see a still
at that phase. Space pauses normal playback. `?t=12` sets a 12-second loop.
Palette overrides use hex without `#`, such as
`?seed=7&bg=f3ecdf&ink=16130f&accent=b5452b`. Defaults are CSS custom properties
in the HTML. No server, package install, or export tools are needed to view it.

With the optional tools below installed:

```bash
node "$SKILL_DIR/scripts/contact-sheet.mjs" out/piece.html out/seeds
bash "$SKILL_DIR/scripts/export-mp4.sh" out/piece.html out/piece.mp4 \
  --seed 7 --duration 12 --fps 30 --width 1280 --height 720
```

The contact sheet contains 12 labeled cells in `out/seeds/sheet.html` and
`sheet.png`, plus one PNG per seed. Choose by eye and record the seed in your
brief. See [the example brief](examples/brief.example.md).

## The 23 systems

Browse by the kind of structure you want to draw. The sequence below also
appears in [systems.json](skill/systems.json); [systems.md](skill/references/systems.md)
explains each drawing and suggests adjustments. Looped strip draws a Mobius surface.

### Attractors

| # | Slug | System | Template |
| --- | --- | --- | --- |
| 1 | `aizawa` | Aizawa attractor | Included |
| 2 | `lorenz` | Lorenz attractor | Included |
| 3 | `clifford` | Clifford attractor | Included |

### Fields and contours

| # | Slug | System | Template |
| --- | --- | --- | --- |
| 4 | `flow-field` | Flow field | Included |
| 5 | `thread-bundles` | Thread bundles | Included |
| 6 | `noise-ridgelines` | Noise ridgelines | Included |
| 7 | `noise-rings` | Noise rings | Included |

### Growth and agents

| # | Slug | System | Template |
| --- | --- | --- | --- |
| 8 | `flocking` | Flocking | Included |
| 9 | `slime-mould` | Slime mould | Included |
| 10 | `differential-growth` | Differential growth | Included |
| 11 | `reaction-diffusion` | Reaction-diffusion | Included |

### Surfaces and forms

| # | Slug | System | Template |
| --- | --- | --- | --- |
| 12 | `ring-stack` | Ring stack | Included |
| 13 | `looped-strip` | Looped strip | Included |
| 14 | `soft-bodies` | Soft bodies | Included |
| 15 | `metaballs` | Metaballs | Included |
| 16 | `raymarching` | Raymarching | Included |
| 17 | `noise-papercut` | Noise paper cut | Included |

### Patterns

| # | Slug | System | Template |
| --- | --- | --- | --- |
| 18 | `stamp-grid` | Stamp grid | Included |
| 19 | `voronoi` | Voronoi relaxation | Included |
| 20 | `halftone` | Halftone | Included |
| 21 | `moire` | Moire | Included |
| 22 | `harmonograph` | Harmonograph | Included |
| 23 | `guilloche` | Guilloche | Included |

## Configuration and optional tools

Installation uses Bash and ordinary filesystem tools. Automation uses Node.js
18 or newer and its built-in modules. Playwright and its Chromium browser are
optional tools for capture and tests; ffmpeg is optional for video export.

The loader tries `PW_DIR` first, then a normal Playwright import. `PW_DIR` is a
directory whose `node_modules` contains `playwright` or `playwright-core`.
For example, prepare a separate tools directory once with network access:

```bash
export PW_DIR="$HOME/.local/share/motion-tools"
npm install --prefix "$PW_DIR" playwright
"$PW_DIR/node_modules/.bin/playwright" install chromium
```

Keep `PW_DIR` exported when running capture commands. If the browser needs
additional operating-system libraries, follow the installation diagnostic for
your system. The generated pieces and acceptance tests do not use the network.

Install ffmpeg with your operating system's package manager and put `ffmpeg`
and `ffprobe` on PATH. Export uses H.264, yuv420p, and faststart; odd dimensions
are padded to even sizes. It replaces the named output file. Temporary PNG
frames are removed when export ends. Set `CRF` from 0 to 51 to control encoding
quality; the default is 23, and lower numbers use more space.

| Setting | Meaning |
| --- | --- |
| `--host claude\|codex\|both` | Select hosts explicitly; default is every detected host |
| `--dir SKILLS_DIR` | Override the skills parent directory for either host |
| `CLAUDE_HOME` | Claude configuration root; defaults to `$HOME/.claude` |
| `CODEX_HOME` | Codex configuration root for detection only; defaults to `$HOME/.codex` |
| `SKILL_DIR` | Shell variable you set to the directory containing Motion's `SKILL.md` |
| `PW_DIR` | Directory for optional Playwright resolution |
| `CRF` | MP4 quality setting |
| `TMPDIR` | Temporary directory for export frames |

When running examples outside a skill session, set `SKILL_DIR` to the installed
directory, such as `"$HOME/.agents/skills/motion"` for Codex or
`"${CLAUDE_HOME:-$HOME/.claude}/skills/motion"` for Claude. With `--dir`, use
`<chosen-skills-directory>/motion`. Capture scripts accept these flags:

| Script | Arguments after input HTML and output path |
| --- | --- |
| `contact-sheet.mjs` | `--width 320 --height 180 --cols 4 --phase 0.33` |
| `render-frames.mjs` | `--seed 1 --duration 4 --fps 30 --width 1280 --height 720` |
| `export-mp4.sh` | Same flags as `render-frames.mjs`; output path is an MP4 |

The frame renderer writes `frame-00000.png` onward. Export duration is separate
from the HTML's playback duration; set `--duration` to match the intended loop.
Missing Playwright makes capture commands exit 2 with a `PW_DIR` hint. Missing
ffmpeg makes MP4 export exit 2 with an installation hint.

## Adapt and verify

Follow [TEMPLATE-CONTRACT.md](skill/references/TEMPLATE-CONTRACT.md) to adapt
any shipped template or add a new system. Keep seed and phase deterministic,
expose `window.renderFrame(i, total)`, honor reduced motion, and keep assets inline.
Adding a system beyond the current 23 also requires updating the registry,
catalogue, this table, and the static test's expected registry together.

Use [web-hero.md](skill/references/web-hero.md) for embedding, a poster, contrast,
and performance checks. Use [rebuild-from-reference.md](skill/references/rebuild-from-reference.md)
to compare against a visual reference one change at a time.

Run from the repository root, without network access:

```bash
node tests/static-check.mjs
node tests/render-check.mjs
bash tests/fresh-user.sh
bash tests/fresh-user-codex.sh
```

The static check requires all 23 registered templates, checks README names and
availability against the registry, and rejects obsolete release wording.
Browser tests inspect every registered template, the 12-cell sheet, and a short
MP4 with ffprobe. Missing templates fail both checks. Without Playwright,
browser tests print `SKIP` and a `PW_DIR` hint. Without ffmpeg, only the MP4 check
is skipped. An installed but broken dependency is a failure. Fresh-user tests
use a temporary HOME and verify installation, backup, custom paths, and removal
for both hosts. They never run either CLI, call a model, or use the network.

The secret-scanning configuration extends the default gitleaks rules. Generated
files in `out/` and MP4 outputs are ignored by Git.

## License

MIT. Copyright (c) 2026 AEIA. See [LICENSE](LICENSE).
