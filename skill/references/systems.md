# Choosing a drawing system

All 23 entries have a working HTML template. The families here follow the order
in `systems.json`. File paths start at the installed Motion directory, beside
`SKILL.md`; they do not start at the project you are drawing in.

Choose a family for its overall structure, then try its templates before tuning
details. A surface needs a readable silhouette; a dense pattern depends more on
spacing. Compare those qualities at the size where the piece will be used.

The loop notes below guide adaptations. Let `p` measure progress through a
cycle, and calculate moving values from `a = p * 2 * Math.PI`. Integer multiples
of that angle give complete oscillations. Make random decisions from the seed
before drawing, so requesting a frame twice produces the same result.

For growth or agent simulations, retain a reproducible snapshot and animate
that snapshot. Advancing a simulation on each draw makes the result depend on
frame order. Check the join by comparing `p=0` with `p=1`, then watch the
frames around it for a speed change. The [drawing contract](TEMPLATE-CONTRACT.md)
covers export and playback requirements.

## Attractors

These systems trace mathematical motion into shapes with many overlapping paths.

### 1. Aizawa attractor

ID: `aizawa`. File: `templates/aizawa.html`.

A curving trajectory wraps a hollow volume and passes through its narrow middle.
The opening provides a useful focal point among the many overlapping turns.

Try adjusting the viewing angle before adding more samples. A translucent stroke
can suggest glass fibres; a darker stroke makes the outer envelope easier to read.

For a loop, calculate a reproducible trajectory and turn the view around it.
Return the camera, light, and stroke opacity to their opening values together.

### 2. Lorenz attractor

ID: `lorenz`. File: `templates/lorenz.html`.

One path alternates between two centres, leaving a paired coil in three dimensions.
Its two-part silhouette stays recognisable even with a spare palette.

Try a shallow view to emphasise the crossings, or a wider margin to isolate the
outline. Thin strokes help keep the inner turns from becoming a solid patch.

For a loop, reuse one integrated path. Rotate it through a complete revolution,
or rock it with an oscillating angle; extra integration during playback would
change the path between visits to the same phase.

### 3. Clifford attractor

ID: `clifford`. File: `templates/clifford.html`.

Repeated trigonometric updates collect points into creases and cloudy patches.
The balance between crowded and nearly empty regions supplies most of the contrast.

Try reducing point density for a dusty print, or shifting the framing until one
crease anchors the image. Compare the distribution of blank space between seeds.

For a loop, begin each evaluation from reproducible coordinates and use the same
iteration budget. Parameter motion must be periodic, and the canvas must be
cleared so pigment does not build up from earlier frames.

## Fields and contours

Use these when direction, spacing, or the rhythm of a line should carry the image.

### 4. Flow field

ID: `flow-field`. File: `templates/flow-field.html`.

Many short paths bend according to a shared direction map. Dense passages and
open channels make the drawing feel like currents across a flat surface.

Try reserving a clear area for a caption, then vary path length or spacing.
A narrow stroke produces a fine drawing; a heavier one joins nearby paths visually.

For a loop, keep the starting locations stable and recalculate their paths.
Move the direction map through a closed sequence of parameters so its final
configuration meets its first.

### 5. Thread bundles

ID: `thread-bundles`. File: `templates/thread-bundles.html`.

Parallel filaments collect into wide, tapering sweeps. Each group follows a shared
curve, while its internal lines make the bending surface visible.

Try fewer groups with larger gaps to expose individual bends. Change filament
spacing for a coarse weave, or use a single hue to emphasise the layered edges.

For a loop, rebuild each central curve from its seed. Coordinate the sideways
offsets and taper with the same cycle, without retaining strokes from past frames.

### 6. Noise ridgelines

ID: `noise-ridgelines`. File: `templates/noise-ridgelines.html`.

Rows of uneven profiles recede across the frame like a drawn terrain. Overlapping
crests create depth without needing a filled three-dimensional surface.

Try compressing the distant rows or lowering the foreground peaks. A stable
horizon gives the eye a resting place while the closer lines move.

For a loop, evaluate a seeded height field along a circular sampling path.
Reconstruct the rows for each phase and paint distant rows before nearer ones.

### 7. Noise rings

ID: `noise-rings`. File: `templates/noise-rings.html`.

Nested outlines share a centre but wander away from perfect circles. Their
changing separation suggests contour maps, ripples, or cut edges.

Try widening the central opening and letting irregularity increase toward the
outside. Keep enough separation for neighbouring outlines to remain distinct.

For a loop, move noise sampling coordinates around a closed orbit. Keep the base
radii stable and bound the perturbation so the rings preserve their hierarchy.

## Growth and agents

These drawings borrow structure from local interactions between many small parts.

### 8. Flocking

ID: `flocking`. File: `templates/flocking.html`.

Small directional marks assemble into travelling groups. Their shared heading
suggests coordinated movement while individual spacing keeps the groups legible.

Try changing the number of groups before increasing their membership. Short,
tapered marks can make direction clearer than round dots.

For a loop, establish the arrangement with reproducible agent steps, then carry
the groups along closed routes. Use each route's tangent to orient the marks.

### 9. Slime mould

ID: `slime-mould`. File: `templates/slime-mould.html`.

A network of trails gathers into trunks, junctions, and faint outer branches.
The thicker routes read as connections between regions rather than separate lines.

Try thinning weaker routes until a few junctions dominate. A small bright accent
can pick out a connection without overwhelming the surrounding network.

For a loop, save the trail map after a fixed preparation run. Animate its sampling
position or intensity with a repeating function instead of depositing new trails.

### 10. Differential growth

ID: `differential-growth`. File: `templates/differential-growth.html`.

An expanding outline develops folds as nearby parts push apart. The result is
a continuous boundary packed with small turns and occasional open pockets.

Try changing the starting boundary or the permitted gap between folds. A simple
outer container can give the intricate interior a clearer overall shape.

For a loop, finish the growth calculation before playback and retain its vertices.
Displace those vertices periodically, with motion smaller than the narrowest gaps.

### 11. Reaction-diffusion

ID: `reaction-diffusion`. File: `templates/reaction-diffusion.html`.

Two coupled quantities spread and react to produce patches and branching channels.
The image can resemble spotted skin or a surface etched by fluid.

Try tuning the scale of the patches first. Leave broad calm regions around a
dense cluster, or soften the boundary to suggest soaked pigment.

For a loop, prepare the concentration texture with a fixed simulation budget.
Warp its lookup coordinates periodically and define how sampling behaves at its
edges, rather than treating continuing chemical change as a repeating animation.

## Surfaces and forms

These systems give the eye an object or layered volume to follow.

### 12. Ring stack

ID: `ring-stack`. File: `templates/ring-stack.html`.

Thin open slices pile into a column that bends sideways. The spaces between
slices reveal the column's depth and the changing direction of its central axis.

Try increasing the gaps or reducing the stack height to expose the interior.
Warm edge shading can suggest wood; sharper contrast makes each slice more graphic.

For a loop, assign every slice a fixed position along the column. Calculate its
centre, angle, and size from that position and a repeating bend function.

### 13. Looped strip

ID: `looped-strip`. File: `templates/looped-strip.html`.

A flat strip joins back onto itself after a half turn, forming a Mobius surface.
As it rotates, the edge and face trade prominence.

Try a narrower strip for a wiry outline or a higher viewpoint to reveal the opening.
Keep shading restrained if the fold should look like paper.

For a loop, leave the mesh unchanged and complete one rotation. If adding a mark
that travels along the edge, account for the two circuits needed to return to its
starting position on this surface.

### 14. Soft bodies

ID: `soft-bodies`. File: `templates/soft-bodies.html`.

Rounded outlines bulge and yield like small inflated objects. Their changing
curvature conveys softness without a detailed surface texture.

Try contrasting one larger body with several smaller ones. Leave clear gaps if
overlap makes it hard to read which outline belongs to which object.

For a loop, settle the spring shapes reproducibly, then animate bounded radial
oscillations. Each oscillation must complete a whole number of cycles per loop.

### 15. Metaballs

ID: `metaballs`. File: `templates/metaballs.html`.

Nearby influence fields join into a single smooth shape. Moving their centres
creates necks that stretch, merge, and separate.

Try reducing the number of centres until each joining event is easy to follow.
The field threshold controls how readily separate masses become connected.

For a loop, give every centre a closed route and derive its position directly
from phase. Any radius animation must repeat too, while staying above zero.

### 16. Raymarching

ID: `raymarching`. File: `templates/raymarching.html`.

Distance-based rendering turns simple volumes into a shaded sculpture. Light and
soft joins can make a spare shape feel solid within an otherwise empty frame.

Try moving the light before adding more geometry. A broad highlight and muted
surface colour can make the form read like unglazed ceramic.

For a loop, pass phase into the inline shader and compute transforms from it.
Avoid dependence on earlier pixels; shape and lighting cycles must share the
same closing point.

### 17. Noise paper cut

ID: `noise-papercut`. File: `templates/noise-papercut.html`.

Irregular layers overlap with small shadows, suggesting a shallow relief made
from cut sheets. The edges carry detail while the filled areas remain quiet.

Try using fewer layers with clearer spacing. Change the edge roughness to move
between carefully cut card and torn paper.

For a loop, calculate the layer outlines from periodic noise coordinates.
Preserve stacking order and a consistent light direction as their edges move.

## Patterns

Choose these for repeated marks, optical interaction, or precise ornamental curves.

### 18. Stamp grid

ID: `stamp-grid`. File: `templates/stamp-grid.html`.

A regular layout combines discs, half-discs, curved corners, and bars. Changes
within the cells produce larger rhythms across the printed-looking surface.

Try altering the proportion of curved and straight marks. Use the accent
sparingly to create a route for the eye through the grid.

For a loop, prepare two seeded arrangements and crossfade with a cosine weight.
Fixed offsets may stagger the cells, but symbol choices should remain stable
through repeated playback.

### 19. Voronoi relaxation

ID: `voronoi`. File: `templates/voronoi.html`.

Each point owns the region closest to it, producing adjoining polygonal cells.
Relaxing the points evens out spacing while preserving an irregular mosaic.

Try outlining the cells without filling them, or concentrate smaller cells near
one edge. A few large regions can give a dense mosaic room to breathe.

For a loop, retain the relaxed point layout and assign small closed motions to
its sites. Recalculate the boundaries from the current positions at every phase.

### 20. Halftone

ID: `halftone`. File: `templates/halftone.html`.

Dots on a regular lattice change size to describe a larger shaded shape.
From a distance the dots merge into tone; close up they remain visible marks.

Try checking the result at its final display size before changing dot density.
A wider gap between dots preserves the printed texture in darker areas.

For a loop, keep the lattice in place and compute radii from a repeating shade
function. An orbiting light or rotating analytic form can drive that function.

### 21. Moire

ID: `moire`. File: `templates/moire.html`.

Two fine patterns overlap to reveal much broader bands. Small changes in their
relative alignment can move those bands across a large part of the image.

Try adjusting pattern spacing before increasing motion. A tiny offset may give
enough activity, especially when text shares the frame.

For a loop, oscillate one layer's position or angle around a fixed alignment.
Review at the intended pixel size to catch flicker caused by fine spacing.

### 22. Harmonograph

ID: `harmonograph`. File: `templates/harmonograph.html`.

Combined oscillations trace an intricate line that contracts toward the centre.
The drawing recalls a pen suspended between moving pendulums.

Try simple frequency ratios and a long drawing interval for clear nested forms.
Change damping to alter how quickly successive turns approach the centre.

For a loop, redraw the complete path over the same internal time interval.
Animate the oscillators' offsets periodically; keep damping tied to drawing
time, separate from the playback clock.

### 23. Guilloche

ID: `guilloche`. File: `templates/guilloche.html`.

Repeated rolling curves interlace into rosettes and ornamental borders.
Their regular crossings give even a single-colour drawing a detailed surface.

Try changing the relationship between large and small lobes. Thin strokes and
an open centre can keep a complex rosette from becoming visually heavy.

For a loop, use fixed frequency ratios and repeatable phase offsets. Draw the
entire curve on every frame with an unchanged sampling budget.
