# Rebuild a reference animation

Use a reference to make visual choices concrete, while keeping the result one
self-contained seeded HTML file.

1. Capture at least 20 frames spaced across a full loop. Keep them as local
   reference files. Record duration, framing, palette, line weight, and density.
2. Identify the closest system or pair of systems in [systems.md](systems.md). Write the
   brief and choose what matters most: silhouette, placement, texture, or pacing.
3. Choose a motion measure before building. For example, compare the fraction of
   pixels whose color changes by more than a fixed threshold between consecutive
   frames. Measure the reference at the same resolution and time interval, then
   use that result as a target. No universal threshold fits every animation.
4. Build a first version, render seeds 1 to 12, and choose by eye. Compare the
   chosen piece to the reference at corresponding phases. Steer one change per
   round and keep the seed fixed during each comparison.
5. Check the loop seam, reduced-motion still, and browser console. Render the
   same seed and phase in a fresh browser context with the same viewport and
   pixel ratio; its hash should match. Use a different viewport for a separate
   composition check, not for hash equality.

Deliver the HTML, selected seed, and any requested MP4. Record the one remaining
visual difference, if any, instead of claiming an exact match without evidence.
