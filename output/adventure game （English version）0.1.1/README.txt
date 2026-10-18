FOREST WANDERER 0.1.1

PLAY: Double-click Forest Wanderer.app. No terminal is needed.
The game is entirely in English.

WASD / Arrow keys: Move
E: Talk / Pick up / Open gate
B: Backpack (click Drop 1 to put a material on the ground)
C: Craft a stone sword (3 branches, 4 rocks, 3 ropes)
Esc: Close a panel / Pause
R after winning: Restart

Quest: Craft your sword, collect 3 blue crystals, reach the northeast gate.
The prototype has no combat, night survival, or save system yet.

0.1.1 changes:
- All game text translated to English.
- Uses Godot's built-in font; no system font dependency.
- Direct app launcher, separate from the Godot editor.
- Defensive item-index validation and pickup diagnostics.
- Full-bag interaction stress test and drop/re-pickup tests added.

Crash status: the reported gameplay exit has NOT been reproduced.
The available macOS crash report came from the development tool's launch check.
A full-bag interaction passed 1000 repetitions in automated logic tests.

Source: main.gd, main.tscn, project.godot. Open project.godot in Godot to edit.
The app contains a copy of the game source; rebuild the app after editing.
Run tests with:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests.gd

Engine: Godot 4.7.2, MIT license. The included engine is from the official macOS download.
