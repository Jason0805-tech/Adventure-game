extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> bool:
	if condition:
		print("PASS  ", message)
		return true
	push_error("FAIL  " + message)
	quit(1)
	return false

func hotbar_slot_for(game: Variant, id: String) -> int:
	var index: int = game.bag.first(id)
	if index < 0: return -1
	var uid: int = int(game.bag.slots[index].uid)
	for slot in range(6):
		if game.hotbar[slot] == uid: return slot
	return -1

func _run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 157
	root.add_child(game)
	await process_frame
	if not check(game.bag.slots.size() == 24, "backpack has 24 slots"): return
	if not check(game.trees.size() > 0 and game.tree_states.size() == game.trees.size(), "trees have persistent harvest states"): return
	if not check(game.workbenches.size() >= 1 and game.ore_veins.size() >= 2, "camp workbench and ore veins exist"): return
	if not check(game.npc_states.has("Rowan") and game.npc_states.has("Ash"), "both NPC rigs are active"): return
	if not check(game.bag.validate(), "empty backpack is valid"): return

	game.bag.add("branch", 2)
	game.bag.add("rock", 3)
	game.bag.add("rope", 1)
	game.craft_recipe(0)
	if not check(game.selected_item().get("id", "") == "stone_axe", "field recipe crafts and equips a stone axe"): return

	var tree_position: Vector2 = game.trees[0]
	game.player = tree_position + Vector2(0, 38)
	game.tree_states[tree_position].hp = 1
	if not check(game.begin_action({"kind": "tree", "pos": tree_position}), "equipped axe starts chopping"): return
	game.action.elapsed = game.action.duration * 0.7
	game.commit_action()
	game.action.clear()
	if not check(not game.tree_live(tree_position), "axe fells the final-hit tree"): return
	if not check(game.bag.count("log") >= 4 and game.bag.count("branch") >= 2, "tree yields logs and branches"): return

	game.bag.add("branch", 12)
	game.bag.add("rock", 8)
	game.bag.add("rope", 8)
	game.bag.add("ore", 5)
	game.craft_recipe(4)
	if not check(game.bag.count("workbench") == 1, "field recipe crafts a placeable workbench"): return
	var placement: Vector2 = Vector2.ZERO
	for y in range(300, 1400, 64):
		for x in range(300, 2100, 64):
			var candidate := Vector2(x, y)
			game.player = candidate - Vector2(0, 80)
			if game.walkable(game.player) and game.can_place_bench(candidate) and game.target_line_clear(candidate):
				placement = candidate
				break
		if placement != Vector2.ZERO: break
	if not check(placement != Vector2.ZERO, "world contains clear workbench placement ground"): return
	game.player = placement - Vector2(0, 80)
	game.facing = Vector2.DOWN
	game.use_selected()
	if not check(game.workbenches.size() == 2 and game.bag.count("workbench") == 0, "workbench places into the world and enters collision/navigation"): return
	game.crafting_station = game.nearby_bench()
	if not check(game.crafting_station >= 0 and game.bench_available(), "placed workbench unlocks advanced recipes"): return
	game.craft_recipe(5)
	if not check(game.bag.count("pickaxe") == 1, "workbench crafts a pickaxe"): return
	game.craft_recipe(6)
	if not check(game.bag.count("fishing_rod") == 1, "workbench crafts a fishing rod"): return

	var pick_slot: int = hotbar_slot_for(game, "pickaxe")
	if not check(pick_slot >= 0, "crafted pickaxe is assigned to the six-slot toolbar"): return
	game.active_hotbar = pick_slot
	var vein: Dictionary = game.ore_veins[0]
	game.player = vein.p + Vector2(0, 38)
	var ore_hp: int = int(vein.hp)
	if not check(game.begin_action({"kind": "ore", "pos": vein.p, "index": 0}), "equipped pickaxe starts mining"): return
	game.action.elapsed = game.action.duration * 0.7
	game.commit_action()
	game.action.clear()
	if not check(int(vein.hp) < ore_hp, "pickaxe damages an ore vein"): return

	var rod_slot: int = hotbar_slot_for(game, "fishing_rod")
	if not check(rod_slot >= 0, "crafted rod is assigned to a toolbar slot"): return
	game.active_hotbar = rod_slot
	var lake: Rect2 = game.pools[0]
	game.player = lake.get_center() + Vector2(0, 130)
	var water: Dictionary = game.nearest_water()
	if not check(not water.is_empty(), "fishing rod finds reachable water"): return
	if not check(game.begin_action(water), "fishing rod begins a cast beside water"): return
	game.action.elapsed = game.action.duration
	game.commit_action()
	game.action.clear()
	if not check(game.bag.count("fish") == 1, "successful cast adds a fish"): return
	var fish_slot: int = hotbar_slot_for(game, "fish")
	if not check(fish_slot >= 0, "caught fish is placed on an open toolbar slot"): return
	game.active_hotbar = fish_slot
	game.fullness = 50
	game.use_selected()
	if not check(game.fullness == 75 and game.bag.count("fish") == 0, "using fish restores fullness"): return

	var axe_slot: int = game.bag.first("stone_axe")
	game.player = placement - Vector2(0, 80)
	game.inventory = true
	game.selected_slot = axe_slot
	var axe_uid: int = int(game.bag.slots[axe_slot].uid)
	var damaged: int = int(game.bag.item_by_uid(axe_uid).durability)
	game.repair_held()
	if not check(int(game.bag.item_by_uid(axe_uid).durability) > damaged, "workbench repairs a selected tool"): return
	game.inventory = false

	var ash_start: Vector2 = game.npc_states["Ash"].p
	for i in range(30): game.update_npcs(0.1)
	var ash_end: Vector2 = game.npc_states["Ash"].p
	if not check(ash_end.distance_to(ash_start) > 1.0 and game.npc_states["Ash"].walk > 0.0, "Ash moves and advances her walking cycle"): return
	if not check(game.bag.validate(), "all inventory changes preserve valid stacks and item ids"): return
	print("ALL_FEATURE_SMOKES_PASSED")
	quit(0)
