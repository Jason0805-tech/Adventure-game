# Current project continuation notes

Latest completed release: output/adventure game 0.1.6.2/.
Authoritative final evidence: tests/0.1.6.2/TEST_RESULTS.txt.

The user explicitly rejected 0.1.6.1's flat procedural leg artwork while
accepting the forward gait logic. Keep original 0.1.6 fur, painted leg edges,
paws and texture. Never restore coloured limb capsules to fix walking.
0.1.6.2 uses unchanged original PNG UVs, exact original idle painting and
continuous distance-driven skin deformation. Source masks and registration
live in assets/animal_atlas.json; assets/animal-skin-topology.bin is mandatory.
The 4px mesh grid is deformation topology, not image resolution reduction.

Use piecewise affine weights on source grid rows to avoid clipped-triangle
folds. Native edge underlaps close actual opaque attachment cuts. Two-pixel
geometric guards gather old toe/fur fragments; do not paint flat patches or
discard flipped painted triangles. Physical profiles and AI remain unchanged.
31 moving-only rest_shift corrections preserve foot size/reach and ground fit.
Do not claim exact world-coordinate no-slip motion in every heading.

Final module/metadata/BIN hashes begin f677cf03/c1710d7b/6559021d. App, previews,
source backup and reusable archive all match these frozen inputs. Final native
coverage is 1,080 poses plus full40×32 geometry; the earlier11,520 native draw
stress is explicitly pre-bias diagnostic evidence. Final39night/260torch pass.

Reusable rig, compiler, source JSON, BIN, original image hash proof and demos:
素材整理/动物/0.1.6.2/. Backups: release-source.zip and full resource SHA manifest.
The user asks for autonomous continuation and saved checkpoints if usage ends.
This release is complete; WORK_IN_PROGRESS.md has a completion header.

Project-root AGENTS.md could not be updated under the active file grant; this
note preserves the intended current release/style correction without writing
outside the three approved 0.1.6.2 directories.
