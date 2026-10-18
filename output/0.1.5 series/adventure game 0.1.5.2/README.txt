FOREST WANDERER 0.1.5.2

PLAY: Double-click Forest Wanderer.app in this folder.
EDIT: Import project.godot in Godot 4.7.2 and press F5.

Changes
- Environment resource nodes replace the fixed trail pickups. Woody shrubs
  occur near trees, fiber grass favors open ground, and stones cluster in
  rocky regions. Each new run changes placement. Dawn renews the same sites.
- Harvested shrubs, stone outcrops and grass leave small depleted remnants.
- Berry shrubs restore 22 fullness immediately when gathered.
- Painted Health and Fullness bars share the parchment and forest palette.
- Low-power nights cause injuries. Starvation drains health during daylight.
  Rest restores 10 health. H consumes medicine and heals 40, capped at 100.
- A single 3D model provides all player poses and right-hand grip locations.
  There are 30-degree views plus exact 45/135/225/315-degree diagonals, eight
  walking poses, and a standing pose. Turns pass through intermediate views.
- Six weapon models attach to the same right hand and follow walking poses.
  The body and hand occlude hidden portions of a weapon.
- Logs, barrels and crates are independent objects with their own depth and
  solid footprints. Passing behind them now gives the correct occlusion.
- Removed the yellow foot ring. Daylight shadows remain.

Controls
WASD / arrows: move. E: gather, eat berries or talk. B: backpack. C: craft.
H: use medicine in daylight. Esc: close a panel or pause. F3: hitboxes.
R: restart after winning or losing.

Survive three nights. Each day lasts 90 seconds. Collect branches, rocks
and fibers to craft weapons. Gear power remains cumulative; the most
recent crafted weapon is held. Material bag capacity: 10. Berries can be
eaten even with a full material bag. Daylight continues in inventory and
crafting menus; Esc pauses it. Closing the game resets progress.

Art: built-in image generation supplied the environment nodes, separated
camp props, HUD icons and painted material swatches. ART_PROMPTS.txt
records the prompts. Model reference: model_reference/traveler-reference.gltf.
Godot license: ENGINE_LICENSES.txt.

Checks and scene previews: ../../tests/0.1.5.2/. Native GUI playtesting was
unavailable in this agent session; automated logic checks and software
scene captures do not establish a native GPU or manual-playtest pass.
