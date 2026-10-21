0.1.6.1 native painted quadruped gait

Body art provenance:
- All five production animal PNGs are byte-for-byte unchanged from 0.1.6.
- Originals, generated source sheets and exact image_gen prompts are archived in ../0.1.6/.
- source-paint-hashes.json proves no original animal bitmap was regenerated, downsampled or edited for this gait change.
- This update extends the existing code-native articulated traveler-rig approach: fixed frame-zero painted body per heading, authored belly contour, four attached pigment limbs.

Runtime:
- animal_gait.gd consumes animal.gait_phase (actual distance / species stride modulo one), metadata, pose and original atlas.
- Every cycle proceeds forwards through support, lift, forward recovery and touchdown. It never plays the same painted keys backwards.
- Rabbit fore/hind bounds, bear four-beat steps, and other quadruped four-beat steps have consistent anatomical leg identities.
- Speed changes the cycle rate. Walk/flee/chase share phase relationships, so a state change cannot swap paws to a different phase.
- Fixed pigment dabs and a native-pixel belly fringe belong to each limb/body contour; randomness never flickers the artwork.
- Limb polygons are explicitly triangulated in local coordinates and batched into one mesh before world translation. This prevents the tiny-polygon native Canvas errors seen near the far world edge.
- Source-cell eyes are registered for wolf/bear; rear-facing poses have no visible eyes.

Perspective approximation:
- The 2.5D projection compresses ground depth to 0.30 of lateral stride; some headings also reduce paw reach to stay inside the established physical ground envelopes.
- Therefore do not claim literal world-space no-slip support at every heading. The complete anatomical support/recovery cycle is distance-driven and visually grounded, but north/south support motion is foreshortened.
- Collision footprints remain unchanged. Expanding them to accommodate literal full-world north/south paw travel would harm the carefully validated passage widths.

Verification:
- tests/0.1.6.1/gait/export_gait.gd: 112,275 checks pass, including 40 heading rigs, support-paw outlines inside existing capsule envelopes, continuous cycle wrap, invariant body UVs, idle/moving geometry and large-world local mesh triangulation.
- Actual native main night-cycle and torch-integration regressions pass with zero gait polygon errors after local mesh submission.
- Sequential GIF and contact sheets are software renderings of the release's exported Canvas geometry and unmodified RGBA bodies; they are not claimed native-GPU screenshots.
- GIF runs phases 0..23 forwards; demo position wraps only after one completed forward cycle.

Build authoring:
- build_rig_metadata.py authors the 40 native body/leg/eye registrations; it reads original metadata and the physical ground envelopes.
- render_gait.py renders exported runtime geometry for QA and does not write production artwork.
