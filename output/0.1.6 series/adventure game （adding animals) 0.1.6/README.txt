FOREST WANDERER 0.1.6 — WOODLAND WILDLIFE

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Open project.godot with Godot 4.7.2 and press F5.

Five new forest animals
- Meadow rabbit: daylight only, up to 4. Hops through grassy clearings and flees from nearby players.
- Woodland deer: daylight only, up to 3. Wanders in woodland and flees from farther away.
- Red fox: daylight and dusk, up to 2. Patrols forest edges and keeps its distance.
- Night wolf: night only, up to 3. Patrols, spots and chases the player, then stops to warn before biting.
- Forest bear: night only, up to 1. Slower, larger and tougher; warns before a stronger swipe.
Activity windows are game design. Species switch immediately with the day/dusk/night phase. Populations stay capped; legal habitat locations refresh over time. Animals avoid solid ground, water, camp and the stone arch passage.

Free night exploration
Each day lasts 180 seconds, followed by 6 seconds of dusk and 90 seconds of night. You remain where you are when the sun sets. Move, gather, fish, craft and fight until dawn. Survive 3 nights to win.
The camp is a refuge: animals keep their distance. Wolves and bears can be outrun. Their ! warning locks their aim and gives you time to move aside or interrupt the attack with a hit.
Inventory, crafting, dialogue and Esc pause time, animals, hunger and actions consistently. The dawn panel advances the next day when you press Enter.

Combat
Equip a blade, axe or pickaxe in slots 1-6. Face an animal, then press Space or click to swing. Hold to repeat. Moving cancels an unfinished swing. Each confirmed hit wears the tool by 1; misses do not. Hits have range, a front arc and a clear path; walls block attacks. Landed hits interrupt predators. Defeated wildlife awards 1 experience each. New animal loot/cooking is not part of this release.
A magic stone carried in the backpack automatically blocks one animal attack and is consumed. H uses medicine for 40 health; fish restores 25 fullness. Keep tools repaired at a workbench.

CONTROLS
WASD / arrows: move.
E: gather, talk, open a workbench. Hold E near a tree/ore/water with the matching tool.
Space / left click: use the selected item or swing a tool.
1-6 / mouse wheel: select toolbar slot.
B: backpack. C: crafting. H: medicine. Esc: close/pause. F3: actual ground contacts. R: restart after win/loss.

Existing gameplay retained
Tree chopping, stumps, mining, fishing, 24-slot backpack, 6-slot toolbar, crafting, repair, ecological resources, NPC walking and the three-night goal remain. Native ground, scenery, human and held-tool artwork and .11 ground contours remain unchanged.
All five animals have 8 headings and 4 independently painted movement keys, with fixed ground anchors and matching heading footprints. Source artwork is kept at native resolution with mipmaps; no global detail reduction.
Closing the app resets progress; persistent saves are not implemented yet.

Art and exact generation prompts: ART_PROMPTS.txt and ../../素材整理/动物/0.1.6/.
Test evidence and actual Canvas previews: ../../tests/0.1.6/TEST_RESULTS.txt.
