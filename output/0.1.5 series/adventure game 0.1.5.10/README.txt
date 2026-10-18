FOREST WANDERER 0.1.5.10

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Open project.godot in Godot 4.7.2 and press F5.

New in 0.1.5.10
- The fixed low-resolution scenery sampling cap is removed. Source texture dimensions and all original base-image pixels are retained; mipmaps handle normal screen minification.
- Ground is a newly painted 2816 by 1920 atlas assembled from four overlapping native painted regions. Main road landmarks are aligned to the earlier map. The ground retains broad, simple oil/gouache brushwork.
- Player, NPC and held-tool animation sheets are freshly rendered at twice the previous resolution from the approved painted source art and the same anatomical rig. Normal frames are 192 by 320; action frames are 384 by 384. This is not an enlargement of the old animation sheets.
- Actor screen size, feet anchors, world stride, movement, original poses and anatomical right-hand grip remain registered. The engine uses half the atlas display scale for the doubled source cells.
- Full-resolution held tools load when selected. Only the currently held normal tool sheet is kept resident, instead of loading all nine large sheets at startup.
- Occlusion depth bands are grouped independently of texture pixel count. Full native texture pixels stay intact, including the separate 17 shore-stone paint layers and full building collisions.
- High-DPI window support is explicit; it was already enabled by default. Movement is still 108 units/second and daylight 180 seconds.

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

Validation details and visual checks: ../../tests/0.1.5.10/TEST_RESULTS.txt.
F3 displays the actual blocking polygons: coral solids include full buildings, trunks and shoreline stones; blue marks water; green marks player feet.
