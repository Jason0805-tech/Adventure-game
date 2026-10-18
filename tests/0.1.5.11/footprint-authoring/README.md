# Ground-plane footprint authoring

`all-48-ground-footprints.jpg` shows every profile at native source crop registration. Coral fill and outlines are physical ground footprints. Blue outlines are the untouched 0.1.5.10 painted solid contours, retained separately for visual masks. Red landmarks are occupied ground points; green landmarks are projected elevated paint or empty ground that must stay physically free. This sheet is an authoring overlay, not a screenshot of the running game.

All 48 model profiles use individually traced ground geometry. The trees retain only root/lower-trunk contact. The closed cabin includes projected wall foundations and the entire projecting stair base, while roof/chimney geometry is visual. The gate has two independent pillar feet and a clear middle route. Its runtime image anchor sits at the right post rather than at image center. Seventeen pond stones each retain a separate, ordered visual contour and newly authored physical ground base. The full water areas remain independently impassable.

The runtime decides which resource classes block movement: soft branch/rope plants and depleted resource remnants may keep authored profiles for visual ordering without acquiring a movement obstacle. These files do not change that policy.

`authoring-results.json`: 48 profiles, 74 physical polygons, 81 visual polygons, 17 individual shoreline stones, 153 art-selected positive/negative landmark checks. `geometry-results.json`: 206 polygon, pairing and render-split checks, no degeneracies or self intersections. The existing visual remnant contour with v=1.02941 is deliberately preserved and is clipped by the texture renderer; all physical coordinates are inside [0,1].

Reproduce with the bundled Python interpreter (Pillow required): run `tests/0.1.5.11/author_ground_footprints.py`, then `check_footprint_geometry.py`. Independent gameplay passage tests are maintained separately and do not select their ground-truth points from these polygons.

`overhead_split_v` is render-only and is present on all 48 profiles. House aliases use v=.55; other substantial props use the rear edge of their physical ground footprint. Water uses0.0 to disable overhead fading. Each pond-rock profile also stores17total paired `overhead_split_vs` values in the unchanged stone order. Root rendering may derive the same per-stone split from the matched ground polygon when cropping each stone. These values do not alter physical blocking.
