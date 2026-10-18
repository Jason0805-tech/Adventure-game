FOREST WANDERER 0.1.5.4

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Import project.godot in Godot 4.7.2, then press F5.

New in 0.1.5.4
- The traveler now uses the approved flat 2D oil/gouache painting style.
  Transparent artwork keeps the forest visible around the painted edges.
- Sixteen headings include 30-degree steps and the exact movement diagonals.
  Character art keeps its original proportions instead of being squeezed.
- Eight walking poses use a shared anatomical motion reference.
- All six tools use the same anatomical right hand. Handles contact the palm,
  follow the wrist, and are naturally hidden by the body when appropriate.
- Boot collision footprints were widened for the new painted character.
- The Mac application includes its engine and opens its own bundled project.

Controls
WASD / arrows: move. E: gather, eat berries or talk. B: backpack. C: craft.
H: use medicine in daylight. Esc: close a panel or pause. F3: hitboxes.
R: restart after winning or losing.

Survive three nights. Each day lasts 90 seconds. Watch the light and timer.
Collect branches, rocks and fibers to craft gear. Bag capacity: 10.
Berries restore fullness immediately, including when the bag is full.
The most recently crafted weapon is held; gear power remains cumulative.
The clock continues in the bag and crafting menus; Esc pauses it.
Closing the game resets progress.

Art source and generation prompts: ART_PROMPTS.txt.
Motion/depth reference: model_reference/traveler-reference.gltf.
Engine licenses: ENGINE_LICENSES.txt.
Checks and scene previews: ../../tests/0.1.5.4/.

Validation uses numerical pose checks, Godot game logic checks, captured
game drawing commands and a headless test of the packaged app launcher.
The native graphics window has not been manually playtested in this session.
