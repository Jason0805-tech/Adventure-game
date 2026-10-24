extends SceneTree
# v0.2.0-alpha.1: felling a tree (or emptying an ore vein) next to the player
# must never leave the player trapped inside the new stump/rubble footprint.
# For every tree and vein, try each spot from which it can be worked, change it
# with the real game code, then check the player stands free and can walk away.
var checks := 0
var failures: Array[String] = []
var g: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func fresh() -> void:
	if g != null: g.free()
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear(); g.phase = "day"
func spots(center: Vector2, kind: String) -> Array:
	var out: Array = []
	for r in range(8, 76, 4):
		for k in range(32):
			var p: Vector2 = center + Vector2.RIGHT.rotated(TAU * k / 32.0) * r
			if not g.walkable(p): continue
			g.player = p
			var t: Dictionary = g.nearest_target()
			if str(t.get("kind", "")) == kind and Vector2(t.pos).distance_to(center) < 1.0: out.append(p)
	return out
func can_walk_away() -> bool:
	var start: Vector2 = g.player
	for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		g.player = start
		for i in range(10): g.move_player(d.normalized(), 0.05)
		if g.player.distance_to(start) > 12.0: g.player = start; return true
	g.player = start
	return false
func chop(tree: Vector2) -> void:
	g.bag.add("stone_axe", 1); g.hotbar[0] = int(g.bag.slots[g.bag.first("stone_axe")].uid); g.active_hotbar = 0
	g.tree_states[tree].hp = 1
	g.action = {"target": {"kind": "tree", "pos": tree}, "uid": g.hotbar[0], "id": "stone_axe", "elapsed": 0.0, "duration": 0.8, "hit": false}
	g.commit_action()

func run() -> void:
	await fresh()
	var trees: Array = g.trees.duplicate()
	# Pass 1 (cheap): which chopping spots end up inside the stump footprint?
	var tried := 0; var inside := 0
	var worst: Array = [] # [tree, spot] pairs that the stump covers
	for tree in trees:
		var candidates := spots(tree, "tree")
		g.tree_states[tree].felled = true; g.rebuild_obstacles()
		for p in candidates:
			tried += 1
			if not g.static_walkable(p):
				inside += 1
				if worst.size() < 60 and (worst.is_empty() or worst.back()[0] != tree): worst.append([tree, p])
		g.tree_states[tree].felled = false
	g.rebuild_obstacles()
	print("STUMP_OVERLAP spots=%d covered_by_stump=%d" % [tried, inside])
	check(tried > 500, "tried many chopping spots (%d)" % tried)
	# Pass 2 (real code): chop at the spots the stump covers.
	var trapped := 0; var stuck := 0; var examples: Array = []
	for pair in worst:
		var tree: Vector2 = pair[0]
		g.tree_states[tree].felled = false; g.tree_states[tree].hp = 3; g.rebuild_obstacles()
		g.player = pair[1]
		chop(tree)
		if not g.tree_states[tree].felled: continue
		if not g.static_walkable(g.player): trapped += 1
		if not can_walk_away():
			stuck += 1
			if examples.size() < 4: examples.append([tree, pair[1], g.player])
		g.tree_states[tree].felled = false; g.tree_states[tree].hp = 3
		g.items = g.items.filter(func(it): return not it.get("dropped", false))
		g.bag = load("res://inventory.gd").new(); g.hotbar.fill(-1)
	g.rebuild_obstacles()
	check(trapped == 0, "felling never leaves the player inside the stump (%d/%d)" % [trapped, worst.size()])
	check(stuck == 0, "the player can always walk away after felling (%d/%d) %s" % [stuck, worst.size(), str(examples)])
	# Ore veins shrink to rubble when mined out.
	var ore_tried := 0; var ore_inside := 0; var ore_stuck := 0; var ore_worst: Array = []
	for i in range(g.ore_veins.size()):
		var vein: Dictionary = g.ore_veins[i]
		var candidates := spots(vein.p, "ore")
		vein.depleted = true; g.rebuild_obstacles()
		for p in candidates:
			ore_tried += 1
			if not g.static_walkable(p):
				ore_inside += 1
				if ore_worst.filter(func(x): return x[0] == i).size() < 3: ore_worst.append([i, p])
		vein.depleted = false
	g.rebuild_obstacles()
	for pair in ore_worst:
		var vein: Dictionary = g.ore_veins[pair[0]]
		vein.depleted = false; vein.hp = 1; g.rebuild_obstacles()
		g.player = pair[1]
		g.bag.add("pickaxe", 1)
		g.hotbar[0] = int(g.bag.slots[g.bag.first("pickaxe")].uid); g.active_hotbar = 0
		g.action = {"target": {"kind": "ore", "pos": vein.p, "index": pair[0]}, "uid": g.hotbar[0], "id": "pickaxe", "elapsed": 0.0, "duration": 0.8, "hit": false}
		g.commit_action()
		if vein.depleted and (not g.static_walkable(g.player) or not can_walk_away()): ore_stuck += 1
		vein.depleted = false; vein.hp = 3
		g.items = g.items.filter(func(it): return not it.get("dropped", false))
		g.bag = load("res://inventory.gd").new(); g.hotbar.fill(-1)
	g.rebuild_obstacles()
	print("ORE_OVERLAP spots=%d covered_by_rubble=%d" % [ore_tried, ore_inside])
	check(ore_tried > 20, "tried mining spots (%d)" % ore_tried)
	check(ore_stuck == 0, "mining out a vein never traps the player (%d/%d)" % [ore_stuck, ore_worst.size()])
	# Last-resort guard: a player already overlapping a solid can still move out.
	var tree0: Vector2 = trees[0]
	g.tree_states[tree0].felled = true; g.rebuild_obstacles()
	g.player = tree0 + Vector2(0, -2)
	for i in range(40): g.move_player(Vector2.DOWN, 0.05)
	check(g.static_walkable(g.player), "a player placed inside a stump can walk out (%s)" % str(g.player))
	print("STUMPS_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty(), "tree_spots": tried, "covered": inside, "chopped_covered": worst.size(), "trapped": trapped, "stuck": stuck, "ore_spots": ore_tried, "ore_covered": ore_inside, "ore_stuck": ore_stuck}))
	quit(0 if failures.is_empty() else 1)
