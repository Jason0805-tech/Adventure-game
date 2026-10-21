# 0.1.6.2 artwork restoration checkpoint — 2026-10-17

FINAL STATUS: completed and validated. The notes below preserve development
history. Use TEST_RESULTS.txt, package-validation.json and release-source.zip
for the final release; output/adventure game 0.1.6.2/Forest Wanderer.app now
contains the final original-painted-leg implementation. Final rig archive:
素材整理/动物/0.1.6.2/. No work remains from this checkpoint.

User asks to restore the attractive original 0.1.6 painted animal legs while
keeping the correct continuous gait. User explicitly says to keep working and
save progress if usage runs out; no acknowledgement/question is needed.

Do not restart or overwrite older releases. All work lives in:
- output/adventure game 0.1.6.2/
- tests/0.1.6.2/
- 素材整理/动物/0.1.6.2/

Current source: animal_gait.gd uses original native atlas UVs, not flat pigment
limb capsules. assets/animal_atlas.json source_skin has 40 authored heading rigs.
assets/animal-skin-topology.bin precompiles source partitioning. No original
PNG or collision file has changed; audit_preserved_art.py passes 56 checks.

First two-bone UV prototype reconstructed original art at rest but had real
painted triangle inversions and visible gaps during movement. Do not treat its
successful startup/package validation as final visual acceptance. The existing
candidate App may still contain that earlier prototype and must be rebuilt.

Active fix: stable continuous vertical translation field for painted limbs,
plus UV-textured edge bridges at real opaque attachment seams. No flipped
painted triangles may simply be dropped, and no flat-colour patch is allowed.
Original paint and the support/forward-recovery cycle must both remain.

Team owners:
- gait_0161: runtime module, source_skin metadata, compiler, cached binary,
  benchmark and reusable archive. Stable-field fix is under native audit.
- ecology_0161: independent compiled UV/source coverage, visible folds, feet
  registration/collision hash checks; native_seams.gd provides real alpha-aware
  boundary pairing including long-to-short clipped edges. Sends helper to gait.
- light_0161: strict painted-fold/native Canvas stress, smoke/night/combat/
  lighting/torch regressions. Original assertions must not be weakened.
- root: main integration, actual Canvas capture/replay, art visual review,
  App packaging, documentation and final source backup.

Root review tools already created:
- make_capture_script.py -> snapshot_game.gd
- capture_release.gd -> eight staged scenes + 32 five-species gait frames
- capture_art_review.gd -> 24 original-paint/continuous-walk comparisons and
  all-painted-headings.png covering 40 headings
- render_captures.cjs supports texture-UV ArrayMesh, source-over alpha and
  final display density; build_art_demo.py assembles the comparison GIF.

Next steps:
1. Wait for gait freeze after field + seam bridge integration, then require
   strict independent visible-fold/ground/seam audits to pass.
2. Re-record/re-render actual final main Canvas frames. Inspect full cycle,
   all headings, seam closure, paws and any webbing between separate legs.
   Existing captures show the rejected prototype and must be replaced.
3. Run the meaningful native/regression suite; inspect logs for errors.
4. Run validate_package.py to rebuild when any source/asset hash changed;
   requires all 65 resources, signature and independent-cwd startup. Backup ZIP
   includes runtime/config/source_skin JSON and compiled BIN.
5. Save honest TEST_RESULTS.txt and final archive. Update project AGENTS.md
   only after final acceptance. Show user the visual result and release folder.

Permissions for this active turn cover the three .6.2 folders above. If a
future session loses them, request only those directories before writing.
