# Native viewport capture feasibility

Tested the locally installed Godot 4.7.2 engine, without opening applications or changing runtime source.

Command: Godot --headless --path output/adventure\ game\ 0.1.5.9 --script ../../tests/0.1.5.9/native-render-probe/probe.gd

The probe creates a 64 x 64 SubViewport, adds an opaque red ColorRect, waits four frames and calls RenderingServer.force_draw(false). The viewport texture reports 64 x 64 but get_image() returns null. The engine logs the dummy rendering texture_storage path. The CLI help lists macos display with metal/vulkan/opengl3 drivers and headless display with dummy only.

Therefore the terminal headless route is suitable for GDScript simulation and actual Canvas command recording, but cannot produce native GPU viewport screenshots on this installation. A report claiming a native screenshot or manual native playthrough based on those commands would be inaccurate. No macos display driver was launched in this probe.

The project's Canvas recorder is a useful reproducible software preview: it records actual release drawing commands, source and prepared texture pixels, atlas source regions, transforms, tint and painter order. Its SVG/Sharp replay is not a GPU frame; interpolation, mipmap sampling and fonts can differ. For this regression, original sprite alpha and draw order suffice to detect painted foreground grass masking a player outside the solid collider.

Recommended independent checks:

1. Simulate actor movement against every active object instance using the actual release movement function.
2. Record positions at the nearest reachable boundary on multiple sides of each instance, preserving actor pose, weapon and final draw order.
3. Replay the actual drawing commands to contact sheets, retaining screenshots for every profile and mirrored variant.
4. Rasterize the actor texture alpha independently and compare against later foreground sprite alpha. Check head and torso visibility separately from the boot capsule. A walkability pass alone does not establish visual correctness.
5. Exempt expected partial canopy occlusion only when it is explicitly faded by runtime drawing; do not exempt buildings or the lower baked-grass fringe merely because the colliders pass.

Artifacts: probe.gd, stdout.log, godot.log, report.json.


## Region-band replay correction

The initial SVG replay introduced vertical seams when contiguous texture bands had fractional destination edges. Independent nested SVG viewports antialiased each strip edge against the background, unlike normal pixel-center triangle coverage. Merely merging uninterrupted runs did not fix boundaries separated by legitimate intervening painter commands.

`render_captures.cjs` now groups only consecutive commands sharing texture, modulation, Canvas transform and pixel-to-world mapping, without moving commands across other painter operations. Non-overlapping touching source spans share a union; actual overlapping translucent draws remain separate to preserve repeated source-over opacity. Texture replay inverse-transforms each output pixel center, applies a half-open source-span coverage test, and samples the full source texture bilinearly before normal compositing. Source image files and release drawing logic are unchanged.

Synthetic tests in `test_replay_regions.cjs` compare one full texture with sixteen strips separated by unrelated painter commands. Normal, mirrored and rotated transforms are pixel-identical (zero differing output bytes). Explicit tests preserve the intervening painter command and translucent overlap multiplicity. Results are in `replay-region-tests.json`.

Visually inspected corrected-cabin-front-280.png, corrected-cabin-front-310.png and corrected-cabin-front-360.png after this change: artificial vertical barcode seams are absent. The files remain software previews. Native filtering, actual mip selection, fonts and final GPU coverage are not validated by the replay.
