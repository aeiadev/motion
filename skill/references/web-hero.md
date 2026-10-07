# Web hero recipes

Choose a system that fits the brief and keep a quiet region behind copy. Start
with `templates/flow-field.html` for an organic line field. The shipped templates
also cover precise contours, cells, halftone, and moire; use the catalogue to choose.

## Embed

For an isolated piece, use a decorative iframe behind semantic content:

```html
<section class="hero">
  <iframe src="piece.html?seed=7" title="Decorative motion"
    aria-hidden="true" tabindex="-1"></iframe>
  <div class="hero-copy"><h1>Your headline</h1></div>
</section>
<style>
  .hero { position: relative; overflow: hidden; background: #f3ecdf; }
  .hero iframe { position: absolute; inset: 0; width: 100%; height: 100%;
    border: 0; pointer-events: none; }
  .hero-copy { position: relative; z-index: 1; padding: 4rem 2rem; }
</style>
```

The embedding page may reference local files; the piece itself stays
self-contained. CSS variables do not cross an iframe boundary, so use the
piece's palette query parameters or edit its defaults.

For inline integration, copy the canvas, style rules, and script into an absolute
layer behind content. Scope selectors to the hero, give its canvas a unique ID,
and replace the standalone viewport rules with container sizing. Mark that
canvas `aria-hidden="true"`. Read the host palette from inherited CSS properties.

## First paint and reduced motion

Render a poster at the chosen seed and phase 0. The frame renderer writes
`frame-00000.png`; copy that image beside the HTML for the host page to use.
Set `SKILL_DIR` to the directory containing the loaded Motion `SKILL.md`, as
described in [the skill instructions](../SKILL.md). Script and template paths
are relative to that directory on either host; keep output in the project.

```bash
node "$SKILL_DIR/scripts/render-frames.mjs" out/piece.html out/poster \
  --seed 7 --fps 1 --duration 1 --width 1600 --height 900
```

Use the poster as the hero's CSS background for no-JavaScript rendering and first
paint. Match its viewport, crop, seed, and palette to the canvas. Reduced motion
must render a complete still without starting a loop. Keep the headline and
other content visible throughout loading and playback.

## Performance

Cap pixel ratio at 2, or lower it for small screens. Skip drawing when the tab is
hidden; in an inline hero, pause offscreen work with IntersectionObserver. Sample
frame times on the target device. If rendering is too slow, reduce thread or
point count, iteration count, or backing resolution, then inspect the result.
Make that choice fixed for exports so every frame uses consistent quality.

## Legibility and visual review

Keep text in HTML above the art. Inspect the whole loop at narrow and wide sizes,
including the most visually busy frame behind the text. Aim for contrast ratios
of at least 4.5:1 for body text and 3:1 for large text. Sample pixels across the
text region, not only an average background color. If contrast fails, lower the
density or opacity, add a quiet region, or use a solid backing behind the copy.

Check resize behavior, reduced motion, focus order, console errors, the static
poster, and the seam in the actual host layout. An attractive contact sheet does
not establish readable text or smooth playback.
