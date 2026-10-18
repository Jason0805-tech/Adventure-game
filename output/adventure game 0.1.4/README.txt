FOREST WANDERER 0.1.4 - PAINTED WOODLAND EDITION

PLAY: Double-click Forest Wanderer.app.
EDIT: Import project.godot in Godot 4.7.

WASD / Arrow keys: move. E: talk / gather. B: backpack. C: craft.
Esc: close an open panel; Esc again: pause. 1/2/3: choose a night action.
F3: toggle collision outlines. Green = player feet; coral = obstacles;
blue = water; gold = NPC feet. On some Mac keyboards use Fn+F3.
Survive three nights. Each day lasts 90 seconds. Open panels do not pause time.

ART AND MOVEMENT
- Fixed top-down 2D perspective with original painterly cartoon assets.
- Player: four actual facing directions, with idle and step poses (8 frames).
- Two NPC designs with front/back views (4 frames).
- Three tree species, one shrub, painted cabin and stone gateway.
- Three appearances each for branches, rocks and rope (9 resource sprites).
- Three painted pond variations placed in the world.
- Soles, contact shadows and foot collisions share one ground anchor.
- Trees, shrubs, cabin, NPCs, pond shores and gate pillars block movement.
- Small movement steps prevent tunneling through obstacles.
- Tree canopies fade when hiding the player.
Small collectible materials are intentionally walkable so they do not trap you.

This is an early art pass. Walking uses two poses per direction, not a full
animation cycle. No save system yet; closing starts a new run next time.
The English interface, recipes, 90-second daylight and three-night rules remain.

Art made with the built-in imagegen tool. See ART_PROMPTS.txt and assets/.
Test scripts, logs and screenshots are in the sibling tests/0.1.4 folder.
Engine license: ENGINE_LICENSES.txt.
