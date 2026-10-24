extends SceneTree
# v0.3.0-alpha.4 feedback patch: the bridge and dock match their art, and low
# sanity / fullness / health hold the traveler back step by step. Uses the real
# game code (movement, interaction, crafting, items, sanity updates).
var checks := 0
var failures: Array[String] = []
var g: Variant
var R: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func fresh(seed: int = 164) -> void:
	if g != null: g.free()
	g = load("res://main.tscn").instantiate(); g.resource_seed = seed; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear(); g.phase = "day"
	R = g.Regions
func walk(direction: Vector2, seconds: float) -> void:
	for i in range(int(seconds / 0.05)): g.move_player(direction, 0.05)
func equip(id: String) -> void:
	if g.bag.count(id) == 0: g.bag.add(id, 1)
	g.hotbar[0] = int(g.bag.slots[g.bag.first(id)].uid); g.active_hotbar = 0
func tick(seconds: float) -> void:
	for i in range(int(seconds / 0.05)): g.survival.update(g, 0.05); g.condition.update(g, 0.05)
func speed_now() -> float:
	g.player = Vector2(1000, 760); var start: Vector2 = g.player
	walk(Vector2.RIGHT, 1.0)
	return g.player.distance_to(start)

func run() -> void:
	await fresh()
	var C: Variant = g.condition
	# --- Bridge: only the plank deck crosses the river -----------------------------
	var mid: float = (R.BRIDGE.x + R.BRIDGE.y) * 0.5
	var art: Rect2 = R.bridge_art_rect(1108.0 / 439.0)
	check(absf(art.position.y + art.size.y * R.BRIDGE_DECK_TOP - R.BRIDGE.x) < 0.5 and absf(art.position.y + art.size.y * R.BRIDGE_DECK_BOTTOM - R.BRIDGE.y) < 0.5, "the painted deck covers exactly the walkable band")
	g.player = Vector2(R.river_x(mid) - 160, mid); walk(Vector2.RIGHT, 4.0)
	check(g.player.x > R.river_x(mid) + R.RIVER_HALF + 30, "walking along the middle of the deck crosses the river")
	for y in [R.BRIDGE.x - 10.0, R.BRIDGE.y + 10.0, R.BRIDGE.x - 30.0, R.BRIDGE.y + 30.0]:
		g.player = Vector2(R.river_x(y) - 160, y); walk(Vector2.RIGHT, 4.0)
		check(g.player.x < R.river_x(y) - R.RIVER_HALF + 4, "beside the bridge (y %.0f) the water stops you (x %.0f)" % [y, g.player.x])
	# Sliding sideways off the deck into the water is impossible too.
	g.player = Vector2(R.river_x(mid), mid); walk(Vector2.UP, 2.0)
	check(g.player.y > R.BRIDGE.x - 2.0, "you cannot step off the deck's far edge into the river (y %.0f)" % g.player.y)
	g.player = Vector2(R.river_x(mid), mid); walk(Vector2.DOWN, 2.0)
	check(g.player.y < R.BRIDGE.y + 2.0, "you cannot step off the deck's near edge into the river (y %.0f)" % g.player.y)
	# --- Dock: its planks are walkable, the water beside it is not ----------------
	var dock: Rect2 = R.dock_walk_rect()
	check(g.static_walkable(dock.get_center()), "you can stand on the ferry dock")
	g.player = Vector2(R.river_x(dock.get_center().y) + R.RIVER_HALF + 40, dock.get_center().y)
	walk(Vector2.LEFT, 3.0)
	check(g.player.x < R.river_x(g.player.y) + R.RIVER_HALF - 20 and g.player.x > dock.position.x - 2, "walking west from the bank onto the dock stops at its west edge (x %.0f)" % g.player.x)
	check(not g.static_walkable(Vector2(dock.position.x - 20, dock.get_center().y)), "water west of the dock is still deep")
	check(not g.static_walkable(Vector2(dock.get_center().x - 10, dock.position.y - 25)), "water north of the dock is still deep")
	g.player = dock.get_center(); var water: Dictionary = g.nearest_water()
	check(not water.is_empty(), "you can fish from the dock")
	# --- Map: one texture for all three regions ------------------------------------
	check(g.ground_layer.map_texture != null, "the world map has a ground texture")

	# --- Speed falls step by step ---------------------------------------------------
	g.health = 100; g.fullness = 100
	var last := 2.0; var monotonic := true
	for s in [100.0, 70.0, 60.0, 50.0, 40.0, 30.0, 20.0, 10.0, 0.0]:
		g.sanity = s; var v: float = C.speed_scale(g)
		if v > last + 0.0001: monotonic = false
		last = v
	check(monotonic, "speed never rises as sanity falls")
	g.sanity = 70; check(is_equal_approx(C.speed_scale(g), 1.0), "no slowdown at 70 sanity or above")
	g.sanity = 50; var at50: float = C.speed_scale(g)
	g.sanity = 30; var at30: float = C.speed_scale(g)
	g.sanity = 0; var at0: float = C.speed_scale(g)
	check(at50 < 1.0 and at30 < at50 and at0 < at30, "a falling sanity bar is felt early (50: %.2f, 30: %.2f, 0: %.2f)" % [at50, at30, at0])
	check(is_equal_approx(at0, C.SANITY_SLOWEST), "at 0 sanity you walk at %.0f%% speed" % (C.SANITY_SLOWEST * 100))
	g.sanity = 100
	check(absf(speed_now() - 108.0) < 0.5, "healthy walking speed is unchanged")
	g.sanity = 0
	check(absf(speed_now() - 108.0 * C.SANITY_SLOWEST) < 1.0, "real movement at 0 sanity is heavily slowed")
	g.sanity = 100; g.fullness = 0
	check(absf(speed_now() - 108.0 * C.HUNGER_SLOWEST) < 1.0, "real movement while starving is slowed")
	g.fullness = 100; g.health = 1
	check(speed_now() < 108.0 * 0.62, "real movement near death is slowed")
	g.health = 1; g.fullness = 0; g.sanity = 0
	check(absf(C.speed_scale(g) - C.MIN_SPEED) < 0.001, "everything at once never stops you completely (%.2f)" % C.speed_scale(g))
	g.health = 100; g.fullness = 100; g.sanity = 100
	# Tool use takes longer as you weaken.
	var base: float = C.action_scale(g)
	g.sanity = 20; g.fullness = 15; g.health = 30
	check(is_equal_approx(base, 1.0) and C.action_scale(g) > 1.5, "weak hands: swings take %.2fx as long" % C.action_scale(g))
	check(not C.can_sprint(g) or g.fullness >= C.SPRINT_FULLNESS, "no sprinting when starving")
	g.sanity = 5; g.fullness = 100; g.health = 100
	check(not C.can_sprint(g), "no sprinting with almost no sanity")
	g.sanity = 100
	check(C.can_sprint(g), "sprinting when well")

	# --- 0 sanity: the hands do nothing ---------------------------------------------
	await fresh()
	C = g.condition
	g.sanity = 0
	var tree: Vector2 = Vector2.INF
	for p in g.trees:
		if g.tree_live(p) and R.region_at(p) == "forest": tree = p; break
	equip("stone_axe")
	g.player = tree + Vector2(0, 40); g.facing = Vector2.UP
	g.interaction_cooldown = 0; g.action.clear(); g.interact()
	check(g.action.is_empty(), "with no sanity you cannot gather or chop")
	g.interaction_cooldown = 0; g.use_selected()
	check(g.action.is_empty(), "with no sanity you cannot swing a tool")
	g.bag.add("branch", 10); g.bag.add("rope", 10)
	var torches: int = g.bag.count("torch")
	g.craft_recipe(Array(g.Data.RECIPES).find(Array(g.Data.RECIPES).filter(func(r): return r.id == "torch")[0]))
	check(g.bag.count("torch") == torches, "with no sanity you cannot craft")
	# ...but food, medicine and a magic stone still work.
	equip("fish"); g.fullness = 50; g.interaction_cooldown = 0; g.use_selected()
	check(g.fullness == 75, "you can still eat")
	check(g.sanity == 0, "food does not restore sanity")
	g.bag.add("medicine", 1); g.health = 100; g.use_medicine()
	check(is_equal_approx(g.sanity, C.MEDICINE_SANITY), "medicine restores %d sanity even at full health" % int(C.MEDICINE_SANITY))
	# --- Ways back: sunlight, a held magic stone; not resting -----------------------
	g.phase = "night"; g.night_elapsed = 30.0; g.player = Vector2(1200, 760); g.sanity = 50; g.torch_lit = false
	g.bag.remove("crystal", g.bag.count("crystal"))
	tick(10.0)
	var dark_loss: float = 50.0 - g.sanity
	check(dark_loss > 3.0, "the dark at night drains sanity (%.1f in 10 s)" % dark_loss)
	equip("crystal"); g.sanity = 50; tick(10.0)
	check(g.sanity > 50.0, "holding a magic stone restores sanity even in the dark (%.1f)" % g.sanity)
	g.hotbar[0] = -1; g.sanity = 50; g.player = g.CAMP + Vector2(0, 20); g.moving = false
	tick(20.0)
	check(is_equal_approx(g.sanity, 50.0), "a lit camp stops the drain but does not restore sanity (%.2f)" % g.sanity)
	g.phase = "day"; g.player = Vector2(1200, 760); g.sanity = 0; tick(10.0)
	check(absf(g.sanity - C.SUN_SANITY_GAIN * 10.0) < 0.05, "sunlight restores sanity (%.2f in 10 s)" % g.sanity)
	g.player = R.PLAZA + Vector2(0, 600); g.sanity = 50
	var before: float = g.sanity; var in_ruins: bool = R.region_at(g.player) == "ruins"
	tick(10.0)
	check(in_ruins and g.sanity < before + C.SUN_SANITY_GAIN * 10.0 * 0.6, "the sun does not help in the ruins (%.2f)" % (g.sanity - before))
	# --- Gradual warnings as sanity falls ---------------------------------------------
	await fresh()
	var said: Array[String] = []
	g.player = Vector2(1200, 760)
	for s in range(100, -1, -2):
		g.sanity = float(s); g.message = ""; g.condition.update(g, 0.05)
		if g.message != "": said.append(str(g.message))
	check(said.size() == 4, "four warnings while sanity falls from 100 to 0 (%d)" % said.size())
	g.sanity = 0; g.message = ""; g.condition.update(g, 0.05)
	check(g.message == "", "a warning is not repeated while you stay low")
	said.clear()
	for s in range(100, -1, -2):
		g.fullness = s; g.message = ""; g.condition.update(g, 0.05)
		if g.message != "": said.append(str(g.message))
	check(said.size() == 3, "three hunger warnings on the way to starving (%d)" % said.size())
	said.clear(); g.fullness = 100
	for s in range(100, 0, -2):
		g.health = float(s); g.message = ""; g.condition.update(g, 0.05)
		if g.message != "": said.append(str(g.message))
	check(said.size() == 3, "three injury warnings as health falls (%d)" % said.size())
	g.health = 100; g.sanity = 100
	check(g.condition.status_line(g) == "Light protects your sanity", "no status complaint when well")
	g.sanity = 0
	check(g.condition.status_line(g).begins_with("Mind gone dark"), "the HUD says when the mind is gone")
	print("ALPHA4_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	g.free()
	quit(0 if failures.is_empty() else 1)
