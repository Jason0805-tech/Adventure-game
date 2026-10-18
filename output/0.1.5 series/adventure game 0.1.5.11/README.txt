FOREST WANDERER 0.1.5.11

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Open project.godot in Godot 4.7.2 and press F5.

New in 0.1.5.11
- Physical collision now uses hand-authored ground footprints, separate from visual outlines. Tree roots, building foundations and steps, prop bases, gate-pillar feet and each shoreline stone remain solid. Elevated roofs, canopies, branches and the arch lintel no longer form invisible ground walls.
- The stone arch can be crossed in both directions through its actual opening. Navigation uses a finer ground grid so NPC pathfinding can also represent the narrow corridor.
- Ground depth determines front/behind order. Elevated paint gently fades when it actually covers the player behind it; roots, foundations and pillar feet remain opaque. The player and held tool remain one coherent drawing unit.
- Small branch/fiber plants and collected remnants stay passable. Water and the closed cabin ground volume stay blocked. Felling, mining, gathering and placing a workbench refresh the relevant collision/navigation state.
- All native 0.1.5.10 artwork is preserved: 2816 by 1920 ground, HD player/NPC/tool atlases, native object source pixels and smooth mipmapped display. No source resolution or pose changes.
- Movement remains 108 units/second and daylight remains 180 seconds.

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

Validation details and visual checks: ../../tests/0.1.5.11/TEST_RESULTS.txt.
F3 displays actual ground blocking polygons: coral marks solid bases, blue marks water and green marks player feet. Visual roofs and tree canopies intentionally extend beyond these footprints.
