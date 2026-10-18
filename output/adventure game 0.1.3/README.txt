FOREST WANDERER 0.1.3 - THREE NIGHTS

PLAY: Double-click Forest Wanderer.app.
EDIT: Import project.godot into Godot.

WASD / arrows: move. E: talk / pick up. B: backpack. C: crafting.
1-6 in crafting: make the selected weapon. Click buttons also works.
Esc: close the current panel; press again to pause the entire game.

Each day lasts 90 seconds. The timer runs while collecting, crafting,
reading dialogue and viewing the backpack. Only Pause freezes it.
Watch the countdown, moving sun, changing shadows and sunset tint.
At zero, the game closes daytime panels and returns you to camp.
After a short dusk transition, choose one action with 1, 2 or 3:
1 Explore: +2 power, -50 total fullness, +1 magic stone.
2 Rest: +1 power, -35 total fullness.
3 Food: +1 power, +1 medicine; food offsets the nightly -30 fullness.

Night 1 requires 3 power, night 2 needs 6, night 3 needs 9.
If power is insufficient, consume a magic stone first, then medicine.
If neither is available, the run ends. Survive night 3 to win.
Press Enter after a successful night to begin the next day.
Materials return at dawn. Carried materials, weapons and unused items remain.
R on the ending screen starts a new run.

Original recipes (branches / rocks / ropes -> added power):
Large stone sword: 3 / 4 / 3 -> 4
Short stone knife: 2 / 2 / 1 -> 2
Stone axe: 2 / 3 / 2 -> 3
Wooden knife: 4 / 0 / 2 -> 3
Wooden sword: 5 / 1 / 2 -> 4
Amazing stone sword: replace a large stone sword + 1 rock -> +1 net power.
Weapons stack their power. Material bag capacity is 10.
Drop surplus materials from the backpack; they remain on the ground until dawn.

Fullness is clamped to 0-100 and gives warnings only, matching the previous
corrected text game. There is no starvation death, manual combat or save system.
The earlier crystal-collection victory has been replaced by three-night survival.
Closing resets the run. All visuals are simple shapes; no external art is needed.

To change daytime length: select the root node and change Day Duration
in the Inspector, or edit day_duration (90.0) in main.gd.
The standalone app contains a snapshot of the source. Rebuild it after edits.

Automated tests:
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests.gd

Engine: Godot 4.7.2. See ENGINE_LICENSES.txt for engine and dependency licenses.
