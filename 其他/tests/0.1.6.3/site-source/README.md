# Forest Wanderer 0.1.6.3

Static, single-threaded Godot4.7.2 web build. `dist` is the complete deployable website; no server or account required. Source scripts are retained in `game-source`; native PNG art is packed unchanged in the payload. The original full project is retained in the owner’s versioned output folder.

The loader reassembles8MiB chunks into original WASM/PCK bytes. It uses the official Engine API and Compatibility/WebGL2 renderer. Canvas policy0 respects CSS safe-area padding at native device pixel ratio. Touch controls use separate finger ownership; modals, focus loss and portrait suspend the simulation. Refresh starts a new run. No persistent savegame added.

Local preview: python3 -m http.server 8763 --bind 127.0.0.1 --directory dist

Full-quality artwork is unchanged. First download approximately107MiB. Actual desktop in-app WebGL2 rendering verified; physical iPhone/Safari testing remains a user-device check.
