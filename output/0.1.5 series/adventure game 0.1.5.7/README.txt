FOREST WANDERER 0.1.5.7

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Open project.godot in Godot 4.7.2 and press F5.

New in 0.1.5.7
- Tree appearances stay fixed while chopping. Hits gently sway the tree around its original root instead of changing its sprite, scale or colour.
- Fine, seeded world-space oil-paint strokes add ground detail without changing the paths. Sprite minification uses mipmaps and matching linear filtering to reduce harsh micro-detail and edge halos.
- 45 sprite variants have individually authored contact contours. All placed solid objects use the corresponding transformed polygons, including mirrored variants, tree stumps, depleted ore, cabin steps, stacked logs, barrels, crates, workbenches, gate pillars and actual water shorelines.
- Actors have rounded boot footprints. Player and NPC movement uses 1.5-unit substeps, including long frames, to prevent crossing narrow contours.
- Rendering depth uses each object's real contact edge, with stable ordering. Shadows draw on the ground; tree-canopy transparency checks real sprite paint over the character.
- Local navigation updates after harvesting keep NPC routes current without rebuilding the whole forest.
- Movement remains 108 world units/second and daylight remains 180 seconds.

Available features
- Chop living trees with an equipped axe. Trees have health and leave a painted stump; a felled tree drops logs and branches.
- Craft a stone axe from gathered branches, rocks and fibers. A stronger iron axe chops faster and lasts longer.
- Craft and place extra workbenches. The camp workbench also unlocks advanced crafting.
- Make and use a pickaxe to mine iron ore veins, then craft stronger gear.
- Make a fishing rod at a workbench. Stand near water and hold E to fish; use caught fish to restore fullness.
- The backpack has 24 stackable slots. Drag items to rearrange them, sort the bag, drop stacks, inspect tool durability and repair tools at a workbench.
- A six-slot toolbar lets you equip tools, food and workbenches. Assign items by dragging them to a toolbar slot, right-clicking an item, or selecting it and pressing 1-6. Use the mouse wheel to switch slots.
- Rowan and Ash now follow forest paths around obstacles and play an eight-direction, eight-frame walking cycle instead of sliding across the ground.
- New tool, stump, ore and workbench art follows the painted 2D forest style.

CONTROLS
WASD / arrow keys: move.
E: gather, talk or open a nearby workbench. Hold E beside a tree, ore vein or water while the matching tool is selected.
Space / left click: use the selected toolbar item or tool.
1-6 / mouse wheel: select a toolbar slot. In the backpack, select an item and press 1-6 to assign it.
B: backpack. C: field crafting; near a workbench this opens advanced recipes.
H: use medicine. Esc: close a panel or pause. F3: show collisions. R: new run after win or loss.

Survive three nights. Each day lasts 180 seconds. Watch the sky tint and timer.
The backpack stores 24 item slots; stack sizes are shown on each stack.
Tools wear down when used and can be repaired at a workbench for 2 branches, 1 rock and 1 fiber.
Felled trees, placed workbenches and mined veins remain changed through the three-day run.
Closing the game resets progress; there is no save system yet.

Art source and generation prompts: ART_PROMPTS.txt.
Motion/depth reference: model_reference/traveler-reference.gltf.
Engine licenses: ENGINE_LICENSES.txt.

Validation details and visual checks: ../../tests/0.1.5.7/TEST_RESULTS.txt.
F3 displays the actual polygon outlines and rounded character footprints.
