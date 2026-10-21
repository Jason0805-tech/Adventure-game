0.1.6.3 web export compatibility audit

Original artwork remains unchanged. All 45 PNG files now have a sibling `.import` containing `[remap]` and `importer="keep"`. This is required for direct original-PNG reads. The recommended resource filter is `*.png,*.json,*.bin`; all game scripts/scenes should be exported as resources. The exact 4.7.2 exporter processes import substitutions after include filtering, so an include filter alone does not preserve an imported PNG. An isolated actual export confirms this: `kept.png` is available to FileAccess, while the identical `imported.png` is represented only by CTEX/import metadata. See [Godot import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/import_process.html#changing-import-resource-type) and [4.7.2 export source](https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform.cpp#L1468).

Use original `res://` paths for Image/FileAccess. Do not globalize packed paths into operating-system filenames. The [ProjectSettings documentation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-method-globalize-path) explicitly warns against globalizing `res://` in exported projects.

Use Compatibility renderer, `variant/thread_support=false`, `variant/extensions_support=false`. Single-thread exports are the official preferred iOS/macOS web route. PWA may be enabled with standalone display and landscape orientation; disable its cross-origin isolation headers when threads/extensions are disabled. Serve HTTPS with `application/wasm` MIME and compressed HTTP transfer for WASM/PCK. See [Godot web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) and [Web export option reference](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html). Runtime-created ImageTextures do not benefit from imported-texture VRAM compression export toggles.

Measured baseline before root's web loading changes:

- 91 startup textures: 433,939,504 bytes native image/mipmap payload (413.84 MiB), plus 72,229,312 bytes retained CPU model images (68.88 MiB).
- `load_art()` took 3169 ms in native headless execution; this is not a mobile-browser timing claim.
- NPC image copies account for 47,185,824 bytes (45 MiB). Dedicated NPC drawing uses AVATAR_ANCHOR and never uses the generic model foot cache, so removing NPC textures from that preprocessing loop preserves visuals while saving these copies and scans.
- Unused-at-start action/armed atlases can be loaded on first need without reducing native resolution. Keep the existing one-selected-tool cache.
- Maximum native texture dimension is 6144. Verify actual browser `MAX_TEXTURE_SIZE >= 6144` rather than assuming a device limit. This audit does not claim an iPhone manual playthrough.
- All source assets total 68.912 MiB compressed on disk. All 45 original PNGs together decode to 1162.497 MiB RGBA8 if loaded simultaneously; most tool atlases are already lazy. This number is not the startup allocation.

Evidence:

- `asset-probe-raw-pck.log`: isolated raw PCK, launched from `/private/tmp`; 45 PNGs/4 JSON/1 BIN, 304,741,675 native pixels; 417 checks, zero failures. Includes source hashes/dimensions, raw-PNG signatures, native buffer and `res://` decoders, all40 compiled topology metadata signatures, and built-in English font metrics. This is not yet the final exported game PCK.
- `raw-fixture-proof.log`: actual Godot export demonstrates Keep File behavior despite an include-PNG filter.
- `startup-texture-inventory.json`: measured native baseline texture/image payload.
- `packaged_asset_probe.gd` can be run with `--main-pack FINAL/index.pck --script ABS/probe.gd -- --manifest ABS/packaged_asset_manifest.json` to verify the final game package.

Final exported package and loader verification:

- `final-web-pck-asset-probe.log`: the actual final `web/game.pck` passes all417 source/native-resolution, JSON, compiled-topology and English-font checks from `/private/tmp`, exit0.
- `web-loader-contract.log`:63 checks over normal startup, incomplete chunk, unavailable WebGL, insufficient texture capability, engine failure, fetch restoration and input release.
- `actual-engine-api.log`:14 checks execute the actual exported4.7.2 Engine/Preloader/Config JavaScript unchanged. Only the native game runtime is stubbed; a real minimal WebAssembly module is compiled. Assembled original bytes satisfy actual stock fetch requests, tracked Response.clone/streaming and PCK filesystem preloading; main-pack arguments and both audio worklet mappings are correct. This is not a real game rendering test.
- `site-payload-audit.log`:56 checks,0 failures;111,953,338 split payload bytes reconstruct the original WASM/PCK exactly. All officialJS/worklet files are copied byte-for-byte and each static binary chunk is at most8MiB. Site loader/shell resource names match the actual export.

Official templates:

The [4.7.2 official release assets](https://github.com/godotengine/godot-builds/releases/expanded_assets/4.7.2-stable) publish the 1.19 GB TPZ, not an individual web export-template asset. The 51.5 MB web-editor ZIP is the editor, not an export template. The [4.7.2 exporter source](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.h#L54) selects `web_nothreads_release.zip` for non-extension, single-thread release. A custom-template path can point directly to that ZIP after extraction.

`extract_official_web_template.py` attempts validated HTTP ranges against the official GitHub TPZ, extracting only `templates/web_nothreads_release.zip`. It uses system curl, rejects missing/wrong Content-Range and excess response sizes, never falls back to a full download, and verifies ZIP CRC while recording the selected-member SHA256. It cannot verify the complete TPZ SHA256 without downloading the entire TPZ. Four offline contract tests pass. This subagent's CLI cannot resolve external DNS, so the parent must run the network step in its authorized network context; an actual network extraction is not claimed here.

The parent subsequently extracted the10,245,903-byte official member through its authorized GitHub release API/range route. `web-template-api/verified-extraction.json` records CRC32 `795d38e9` and memberSHA256 `d3ee2f08cef0cf3cf6678a6355a92a8db48ccdd35cbd2e8bfd5f0e8a0b4032a0`; the completeTPZ SHA256 remains unverified because the full archive was not downloaded.

Official complete-TPZ URL: https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz

Official complete-TPZ SHA256 reference: `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`.

Final browser mesh lifetime fix: `world_lighting.gd` now retains and reuses its actual Canvas mesh on the lighting instance. CanvasItem.draw_mesh submits only a RID, so the previous local-only resource could disappear before deferred GLES3 bounds/surface queries. Animal meshes already had persistent caches and were unchanged. `test_canvas_mesh_lifetime.gd` reproduces25 failures before the fix and passes125 checks after: retained lifetime, reused identity, unchanged vertex/color/index arrays over24dawn/dusk/night/torch/resize cases, independent software capture snapshots. Existing2794 lighting and260torch integration checks also pass. Final loader uses official canvasResizePolicy0 and ResizeObserver to preserve stage safe-area padding and DPR backing resolution; both loader contract and actualEngineAPI tests validate this path.

Final orientation/focus regressions:63 loader contract checks include both natural and forced `?touch=1` mode, portrait suspension and landscape restoration, hidden/blur preservation, focus/visibility restoration without requiring resize, and focus rejection while portrait. The final exportedPCK additionally passes the125mesh-lifetime regression directly. Source art and animal gait metadata are unchanged.
