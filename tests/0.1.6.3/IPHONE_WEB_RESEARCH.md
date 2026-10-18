# iPhone Web QA notes

## Available local tooling (verified on this machine)

- Bundled `playwright-core` 1.62.1 exists. Its expected Chromium, WebKit and Firefox executable paths do not exist; no cached Playwright browser directory was found.
- Installed Google Chrome and Safari exist. `safaridriver --version` reports Safari 27.0. macOS is 26.6.2. Xcode, `simctl` and Safari Technology Preview are unavailable.
- Installed-Chrome headless launches were attempted with Playwright. Chrome aborted before any page opened (`SIGABRT`, target closed; cleanup also reported `EPERM`). The failed probe is saved in `browser-probe-result.json`.
- After the parent authorized a browser download, patched Playwright WebKit26.5/v2336 was installed under `/private/tmp/forest-wanderer-webkit-0163/`. Download completed, but this engine also aborted before creating any page (`Abort trap:6`, exit134). `webkit-install.log` and `webkit-probe-result.json` record these distinct outcomes. No browser security/Remote Automation preference was changed.
- Only crash reports for the exact probe PIDs were inspected. Both engines terminate in macOS application registration before page startup: Chrome's stack includes `_RegisterApplication` / `TransformProcessType`; patched WebKit includes `_RegisterApplication` / `NSApplication init`. These failures establish a browser-launch limitation in this execution context. They do not establish a game/WebGL incompatibility, and no iPhone/browser result is claimed from either probe. A separate supported Node REPL module import also failed before launch because the bundled CommonJS module wrapper was unavailable there.
- Playwright can use installed Chrome. Its WebKit requires its own patched binary, and cannot control branded Safari. Device presets emulate viewport, user agent, pixel ratio and touch capability; they do not turn desktop Chrome into mobile Safari or a physical iPhone. [Playwright browsers](https://playwright.dev/docs/browsers), [device emulation](https://playwright.dev/docs/emulation).
- Native Safari WebDriver is built in, but Remote Automation must be enabled and initial authorization may be required. Its automation windows are isolated from ordinary browsing. This audit has not enabled that preference or claimed a Safari run. [WebKit Safari WebDriver](https://webkit.org/blog/6900/webdriver-support-in-safari-10/).

## Export and startup

Godot Web needs WebAssembly and WebGL2 through the Compatibility renderer. Godot's current docs prefer single-threaded export for macOS/iOS; only threaded/extension exports require cross-origin isolation headers. Serve `.wasm` as `application/wasm`, keep exported companion filenames intact, and use HTTPS. A clear initial tap is useful because audio/fullscreen can require a current user gesture. Background tabs can suspend processing; unfocused windows are a distinct case. The docs also warn that Safari has WebGL2 issues. These requirements support single-threaded export plus an explicit Start/Resume affordance; they do not establish actual iPhone compatibility without browser/device testing. [Godot Web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## Pause and stuck-input risks

Use `visibilitychange` to distinguish hidden content from an unfocused window. Browser animation callbacks often stop in hidden tabs and timers are throttled; elapsed wall time should not be applied as a large game update when returning. Independent game focus/visibility handling should clear all active finger/held-action state, pause the entire simulation and require a deliberate resume if already paused. A blur/focus pair alone is not a reliable visibility signal. [Page Visibility API](https://developer.mozilla.org/en-US/docs/Web/API/Page_Visibility_API).

A portrait/landscape transition should clear active touches before resizing. Preserve an existing inventory/craft/dialog or manual pause, rather than automatically resuming because landscape returned. Test hiding a page while attacking and while dragging an item, then releasing the physical finger while the page is hidden.

## Viewport and safe areas

Mobile layout and visual viewports can differ. Browser bars, zoom and viewport changes may alter the visible region; `visualViewport` exposes resize/scroll and its offsets. Avoid relying on one initial `innerHeight` measurement. [VisualViewport](https://developer.mozilla.org/en-US/docs/Web/API/VisualViewport).

If using `viewport-fit=cover`, apply `env(safe-area-inset-*)` to the actual interactive canvas container/controls. Otherwise landscape controls can sit under the camera cutout or Home indicator. Keep CSS sizing and Godot's local canvas coordinate mapping consistent. [WebKit safe areas](https://webkit.org/blog/7929/designing-websites-for-iphone-x/).

## Touch and cancellation

Apply `touch-action:none` to the game interaction region to prevent a joystick drag becoming a native pan/zoom gesture. Treat cancellation like release and clear the corresponding finger. Pointer capture keeps movement attached when leaving a target; cancellation and compatibility mouse events still require care. Avoid handling the same touch as both a finger action and an emulated mouse click. Godot's touch indices must remain independently owned, so releasing an attack finger does not release the movement finger. [Pointer events](https://developer.mozilla.org/en-US/docs/Web/API/Pointer_events).

## Independent test scenarios to run after the mobile API is integrated

1. Portrait blocks play and freezes clock, actors, hunger, torch fuel and attack state. Rotating to landscape clears old touches and does not undo an explicit/manual pause.
2. Joystick down/drag moves at the real player's speed; a second attack finger triggers attack without stealing movement. Release/cancel each finger in both orders; no stuck walk/attack remains.
3. Bag/craft/dialog pauses the same simulation; game-control touches cannot swing behind the modal. Touch drag rearranges a stack; a separate finger does not drop/swap it unexpectedly.
4. Touch recipe buttons, crafting pagination, close/resume, hotbar selection, torch and healing use the same gameplay paths as desktop inputs. A canceled touch or an up outside its original control must not invoke a second action.
5. Background/focus loss during movement, item drag and held attack clears touch state; return/resume cannot replay an old action or catch up elapsed survival time.
6. Browser viewport cases include a compact iPhone landscape, a large landscape, portrait, expanded/collapsed browser bars and a safe-area inset. Any browser screenshot must name the actual engine and emulation method.

The source atlas audit already records about1.16GiB if all PNGs were decoded to RGBA simultaneously; this is not necessarily concurrent residency. Test startup/memory on the actual export and query WebGL2 `MAX_TEXTURE_SIZE` rather than inferring support from desktop success. Preserve native artwork; do not silently lower source resolution to pass mobile checks.

## Actual release-scene input/lifecycle evidence

`mobile_actual_input_qa.gd` runs the unmodified release main scene through real Godot `InputEventScreenTouch` / `InputEventScreenDrag` objects and native lifecycle callbacks. It passed235 checks (result and exact source hashes: `mobile_actual_input_result.json`). Independently verified real ground geometry admits the movement fixture, and real108world-unit/s movement, walking distance, sword action and Gather inventory path all run. Multi-touch release/cancel in either order, modal contact quarantine, one menu-drag owner and cancellation were verified.

Backpack, crafting, dialogue, manual pause, hidden/focus loss and actual portrait viewport freeze player/time/vitals/torch item fuel/NPC state/animal state and RNG. Focus/landscape return preserves an existing manual pause, old touches cannot revive movement or item dragging, and a25-second return delta advances only the existing50ms frame cap. This is native headless scene/state QA; it is neither a WebGL rendering test nor physical iPhone testing. Native `_draw` submits Canvas commands in this mode but does not provide a GPU screenshot. The parent owns the separate in-app-browser export startup test.
