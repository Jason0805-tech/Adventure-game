# 0.1.5.9 depth audit

This audit reads the previous release's actual trimmed textures and the current authored collision contours. It does not change their geometry and is not a manual native playthrough.

The reported cabin case is reproducible by the old rendering rule: one `depth_v=0.96386` belongs to the bottom stair. Painted foliage at the left wall is therefore drawn in front of a legal actor below that wall but above the stair. The collider is correct; extending all collision out to grass would incorrectly turn grass into an invisible wall. At source U=0.40 the local wall/ground contact is 27.52 world units above the global depth. Median per-column difference is 27.36 units.

The same scalar rule affects the sloping undersides of stacked logs, workbenches, containers, ore rocks, stumps and resource/remnant sprites. `profile-depth-variation.json` records measurements for every available profile; some extreme silhouette side points and tree/gate gaps are intentionally passable and must not be treated as newly required collision.

The original ponds were painted wholly in the ground pass. Consequently their shore rocks had collision but never appeared in front of an actor behind them. The new module partitions all 17 rock contours into independent cropped paint layers, leaving water and the rest of the pond on the ground. Rock pixels have exactly one owner. Pixels removed from the base are included unchanged in the cropped layer; the source image is never edited.

`depth_layers.gd` caches one-texel vertical source bands. Each band sorts against the lower solid contour in its own column. Missing outside columns extrapolate the nearest supported column; the gate's internal open passage keeps the original header depth. Live tree canopy painting/fading stays with main.gd. All other static models, including shrubs, can use the same band API. A column's source pixels are drawn once, at the same world rectangle and mirror transform as before.

`test_depth_layers.gd` independently tests local slope depths, continuous nonoverlapping bands, missing-column extrapolation, arch/pillars, cache reuse, unchanged source images, synthetic overlapping masks and all three real pond texture partitions. 70,132 assertions pass. The exact alpha checks cover 34,365 actual pond pixels plus 640 synthetic pixels, with both conservation and exclusive ownership at every pixel. These module tests complement, and do not replace, main-scene movement/contact replays.

## Integrated ordering and CPU sampling

A subsequent main.gd correction keeps the actor's body coherent across neighboring depth columns: after boots pass their own local front by 2 world units, columns intersecting the actor's ±40-unit horizontal body span sort just before that actor. The mirrored local-X query and transformed strip intervals use opposite X signs consistently; Y depth is unchanged by mirroring. The 0.02 depth separation is larger than the 0.001 stable-sort tie tolerance. Gate pillars participate; an unsupported center column retains the authored overhead-header depth.

`benchmark_depth.gd` samples 100 cached iterations for each region at viewport 1100×720. Current results: camp 489 visible paint entries, 2.762 ms mean; forest 243 entries, 2.028 ms; pond 453 entries, 3.011 ms. Full-world construction produces 790 entries at 4.041–4.439 ms. Band cache entries stay at 109 throughout. Recorded Canvas command totals are 931/686/896 respectively. Instrumented full command assembly is 5.55/6.33/7.34 ms mean, including recorder metadata/dictionaries; those numbers are not native frame time, GPU duration or FPS. Timings are a single local headless run and can vary with concurrent work. See `../depth-cpu-benchmark.json`.
