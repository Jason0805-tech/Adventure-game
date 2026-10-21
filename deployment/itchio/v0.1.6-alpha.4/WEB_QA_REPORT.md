# Forest Wanderer — HTML5 / itch.io QA Report

**Build:** `v0.1.6-alpha.4`  
**Engine:** Godot 4.7.2  
**QA date:** 2026-10-21  
**Status:** Local ZIP and browser build checks passed. **An actual itch.io-hosted page has not been verified, so this build is not yet confirmed ready for release.**

## Deliverable

- ZIP: `deployment/itchio/v0.1.6-alpha.4/Forest-Wanderer-v0.1.6-alpha.4-itchio.zip`
- Exact local path: `/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/deployment/itchio/v0.1.6-alpha.4/Forest-Wanderer-v0.1.6-alpha.4-itchio.zip`
- ZIP size: **81,692,618 bytes** (77.9 MiB)
- Extracted size: **116,625,718 bytes** (111.2 MiB), 27 files
- Largest archive member: **8,388,608 bytes** (8 MiB)
- Maximum archive path length: **30 characters**
- SHA-256: `d86b5f7b4b552153d85c4dfc7e34a0274f077c04e55baedb69a880048ca7ead5`
- Reconstructed `game.wasm`: **39,514,754 bytes**, SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`
- Reconstructed `game.pck`: **73,072,580 bytes**, SHA-256 `38dda7e255ca013864e951e0884da9987d21c0d51f0ac7c4fcbee5732147eacd`

The archive passes the requested limits: fewer than 1,000 files, under 500 MB extracted, every file under 200 MB, and every path under 240 characters. `index.html` is at the archive root. ZIP CRC checks pass, paths are unique and relative, and the WASM/PCK payload chunks reconstruct byte-for-byte to the hashes recorded in `payload.json`. The payload identifies itself as `v0.1.6-alpha.4`.

## Archive structure

```text
Forest-Wanderer-v0.1.6-alpha.4-itchio.zip
├── index.html
├── loader.js
├── game.js
├── game.audio.worklet.js
├── game.audio.position.worklet.js
├── payload.json
├── manifest.webmanifest
├── LICENSE.txt
├── ENGINE_LICENSES.txt
├── cover.png
├── meadow.jpg
├── icon.png
├── app-icon-rowan.png
└── data/
    ├── game.wasm.00.bin
    ├── game.wasm.01.bin
    ├── game.wasm.02.bin
    ├── game.wasm.03.bin
    ├── game.wasm.04.bin
    ├── game.pck.00.bin
    ├── game.pck.01.bin
    ├── game.pck.02.bin
    ├── game.pck.03.bin
    ├── game.pck.04.bin
    ├── game.pck.05.bin
    ├── game.pck.06.bin
    ├── game.pck.07.bin
    └── game.pck.08.bin
```

The build was freshly exported with the Godot 4.7.2 single-threaded Web preset and the project's no-thread release template. It does not require `SharedArrayBuffer`. The packaged JavaScript, WASM and PCK all load from relative paths. As required for the final game, the build copy removes the F3 collider-debug shortcut; the historical source and published releases were not changed.

## Asset and version checks

- The requested source project's `project.godot` and exported payload both identify `v0.1.6-alpha.4`.
- 169 local project files were scanned; no Git LFS pointer stubs or zero-byte files were found. The 45 native PNG game assets were present as image data. The available environment did not permit checking the remote Git LFS object store.
- The build retained the original art. Source-preservation checks recorded 59 unchanged native/runtime assets and no mismatches before the release-only debug-shortcut cleanup.
- The ZIP was extracted and checked independently; CRC, file count, path, size-limit, payload-version and payload-hash checks passed.

## Test environment

Browser checks used the **Codex In-App Browser**, a Chromium-based browser with WebGL 2, served over local HTTP from the extracted final ZIP. Tested viewport sizes were 1280×720 (desktop), 844×390 and 568×320 (landscape mobile-size emulations). These are viewport emulations, not physical devices.

No physical iPhone, Safari-on-iPhone, WeChat browser, or itch.io-hosted page was tested. `file://` direct opening was not tested.

Screenshots captured from the final ZIP are stored under `../../../tests/0.1.6.4/itchio-package/`: `browser-final-itchio-desktop.png`, `browser-night1-dark.png`, `browser-mobile-844x390.png` and `browser-mobile-568x320.png`.

## Results

| Area | Result | Evidence / scope |
|---|---|---|
| Fresh Web export and package | **PASS** | Godot export completed; final ZIP has root `index.html`, 27 files and valid payload hashes. |
| Local browser startup | **PASS** | Extracted ZIP reached `GAME_READY v0.1.6-alpha.4` and entered the game in WebGL 2; no browser error logs were observed. |
| Keyboard focus and movement | **PASS** | Held-key movement worked in the browser. |
| Gathering and inventory | **PASS** | Gathered fibers and a rock; the bag count updated. Bag and Craft panels opened and closed. |
| Food and hunger | **PASS** | Ate gathered berries; fullness increased in the browser. Additional survival checks passed. |
| Lighting and day/night | **PASS, partial browser scope** | The browser run showed daylight, dusk, night 1 and the darkened scene/camp light. Automated survival/night tests cover the longer cycle. |
| Pause and simulation freeze | **PASS** | Menus pause time and actor simulation in the release tests; opening the bag in-browser held the displayed timer. |
| Wildlife spawning, nights 1–3 | **PASS in deterministic game tests** | Night 1: 2 wolves + 1 bear; night 2: 3 wolves + 1 bear; night 3: 3 wolves + 1 bear. Each spawn stayed at least 360 world units from the player, renderer entries/fade completed, and daytime despawn passed. |
| Predator AI and combat | **PASS in automated game tests** | 72 predator checks passed, covering pursuit/warnings/attacks, bear charge, collision, camp response, passive species and spawn limits. |
| Three-night survival | **PASS in automated campaign scenarios** | 15 campaign checks passed across six deterministic scenarios. Prepared runs survived all three nights for seeds 164, 271 and 407. This was automated camp-focused simulation, not a full manual exploration playthrough. |
| Mobile landscape layout | **PASS visually** | Cover and game HUD/controls rendered at 844×390 and 568×320. Godot synthetic touch/lifecycle tests passed 3,106 checks. Browser automation here did not provide true touchscreen input; no physical-device interaction is claimed. |
| Debug shortcut | **PASS** | F3 did not show a collider overlay in the final browser package. |
| Actual itch.io page | **BLOCKED / UNVERIFIED** | No upload or publication was performed, as requested. Therefore the final itch embed and its page-level launch cannot be confirmed. |

### Night predator visibility finding

The earlier suspicion that wolves and bears might not spawn at night was **not reproduced as a spawn-logic failure**: deterministic checks found the expected wolves and bear on all three nights, with spawn distance, renderer registration, fade-in and daytime despawn checks passing. In the natural browser sample, night 1 was reached but no wolf or bear was visible in the sampled viewport. Because spawns are randomized, can be off-screen, and are difficult to see in darkness, that observation does **not** establish a rendering bug. Browser-visible predator encounter/rendering across all three nights remains unverified.

## Confirmed failures and remaining limitations

- No reproducible startup, loading, asset-path, or gameplay failure was found in the tested local-browser path.
- The release requirement “launch directly from an itch.io HTML5 page” remains **unverified**. Verifying it requires the ZIP to be uploaded to an itch.io draft page and launched there; this was deliberately not done because the request forbids uploading or publishing. Do not treat this ZIP as an itch-verified release until that check is completed.
- A full manual three-night exploration/combat playthrough was not performed. Night spawning and campaign logic were tested with deterministic automated scenarios.
- Real touch interaction and device-specific layout/performance on iPhone Safari and WeChat remain unverified. Landscape layouts were checked at emulated viewport sizes; synthetic Godot touch tests are separate from physical-device testing.
- Remote Git LFS server state could not be queried; the local working copy contains complete asset bytes, not pointer stubs.

No commits, pushes, uploads, or publication actions were performed.  
The itch.io root-index and browser-build requirements are documented in [itch.io's HTML5 upload guide](https://itch.io/docs/creators/html5).
