extends SceneTree
# v0.1.8 Quest & Progression: journal tabs, landmark discoveries and rewards,
# recipes learned by exploring, supply caches, exploration milestones and
# quest-step announcements. Uses real game functions throughout.
var checks := 0
var failures: Array[String] = []
var g: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = pressed
		Input.parse_input_event(e); Input.flush_buffered_events()
func reachable(a: Vector2, b: Vector2) -> bool:
	var from: Vector2i = g.nav_cell(a); var to: Vector2i = g.nav_cell(b)
	return from.x >= 0 and to.x >= 0 and not g.nav_grid.get_id_path(from, to).is_empty()
func stand_near(site: Vector2, max_r: float) -> Vector2:
	for r in range(0, int(max_r), 12):
		for k in range(24):
			var p: Vector2 = site + Vector2.RIGHT.rotated(TAU * k / 24.0) * r
			if g.walkable(p) and reachable(g.CAMP, p): return p
	return Vector2.INF

func run() -> void:
	Input.use_accumulated_input = false
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear(); g.phase = "day"
	var P: Variant = g.progression
	# --- Supply caches ----------------------------------------------------------
	var cache_bodies: Array = g.solid_bodies.filter(func(b): return b.kind == "cache")
	check(cache_bodies.size() >= P.CACHES.size(), "every cache has a ground collision body")
	for body in cache_bodies:
		check(Rect2(Vector2.ZERO, g.WORLD).encloses(body.bounds), "cache %d inside the world" % body.index)
		for other in g.solid_bodies:
			if other.id != body.id and other.kind != "cache":
				check(not g.Geometry.polygons_overlap(body.polygon, other.polygon), "cache %d footprint clear of %s" % [body.index, other.id])
	for i in range(P.CACHES.size()):
		var stand := stand_near(P.CACHES[i], 90.0)
		check(stand != Vector2.INF, "cache %d reachable from camp" % i)
		if stand == Vector2.INF: continue
		g.player = stand; g.interaction_cooldown = 0
		check(str(g.nearest_target().get("kind", "")) == "cache", "cache %d is the interaction target" % i)
		var before: int = g.bag.used_slots() + g.items.size()
		g.interact()
		check(P.opened[i], "E opens cache %d" % i)
		var loot := 0
		for id in P.CACHE_LOOT[i]: loot += g.bag.count(id)
		check(loot > 0 or g.items.size() > before - g.bag.used_slots(), "cache %d gives its supplies" % i)
		g.interaction_cooldown = 0
		check(str(g.nearest_target().get("kind", "")) != "cache" or int(g.nearest_target().get("index", -1)) != i, "opened cache %d is no longer a target" % i)
		check(not g.walkable(P.CACHES[i] + Vector2(0, -3)), "opened cache %d keeps its ground base" % i)
	var titles: Array = [P.banner_title]
	for b in P.banner_queue: titles.append(b[0])
	check(P.opened_count() == P.CACHES.size() and titles.has("SUPPLY CACHE 4 / 4"), "caches announce their count (queued after the intro banner)")
	# --- Landmarks and learned recipes ---------------------------------------
	g.bag = load("res://inventory.gd").new(); g.hotbar.fill(-1)
	var iron: int = -1
	for i in range(g.Data.RECIPES.size()):
		if g.Data.RECIPES[i].id == "iron_axe": iron = i
	g.bag.add("log", 2); g.bag.add("ore", 3); g.bag.add("rope", 2)
	g.player = stand_near(g.workbenches[0].p, 80.0); g.crafting = true; g.crafting_station = 1
	check(not P.recipe_learned(g.Data.RECIPES[iron]), "iron axe starts locked")
	g.craft_recipe(iron)
	check(g.bag.count("iron_axe") == 0 and g.bag.count("ore") == 3, "locked recipe crafts nothing and costs nothing")
	g.crafting = false
	for mark in P.LANDMARKS:
		var stand := stand_near(mark.pos, float(mark.radius) * 0.8)
		check(stand != Vector2.INF, "%s can be reached on foot" % mark.name)
		if stand == Vector2.INF: continue
		g.player = stand
		var had: Dictionary = {}
		for id in mark.get("give", {}): had[id] = g.bag.count(id)
		P.banner_time = 0.0; P.banner_queue.clear()
		P.update(g, 0.1)
		check(P.discovered.has(mark.id), "walking to %s discovers it" % mark.name)
		check(P.banner_title == "DISCOVERED: " + str(mark.name), "%s shows its own discovery banner" % mark.name)
		for id in mark.get("give", {}):
			check(g.bag.count(id) >= int(had[id]) + int(mark.give[id]) or g.items.any(func(it): return it.kind == id and it.get("dropped", false)), "%s rewards %s" % [mark.name, id])
		if mark.has("learn"): check(P.learned.has(mark.learn), "%s teaches %s" % [mark.name, mark.learn])
		check(g.map_view.seen(mark.pos), "%s is revealed on the map" % mark.name)
		var count_before: int = P.discovered.size()
		P.update(g, 0.1)
		check(P.discovered.size() == count_before, "%s is only discovered once" % mark.name)
	g.player = stand_near(g.workbenches[0].p, 80.0); g.crafting = true; g.crafting_station = 1
	g.craft_recipe(iron)
	check(g.bag.count("iron_axe") == 1, "after the Rune Stone the iron axe can be crafted")
	g.crafting = false
	# --- Exploration milestones ------------------------------------------------
	# Fresh run: milestones rewarded in order, each exactly once.
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear(); g.phase = "day"; P = g.progression
	var fish_before: int = g.bag.count("fish")
	for x in range(0, 2200, 120):
		for y in range(0, 1500, 120):
			if float(g.map_view.percent()) < 30.0: g.map_view.reveal(Vector2(x, y), 150.0)
	P.update(g, 0.1)
	check(P.milestones_done[0] and not P.milestones_done[2], "25%% milestone rewards once (explored %d%%)" % g.map_view.percent())
	check(g.bag.count("fish") >= fish_before + 2 or g.items.any(func(it): return it.kind == "fish" and it.get("dropped", false)), "25% milestone gives fish")
	for x in range(0, 2200, 60):
		for y in range(0, 1500, 60): g.map_view.reveal(Vector2(x, y), 80.0)
	P.update(g, 0.1)
	check(P.milestones_done[1] and P.milestones_done[2], "50% and 75% milestones reward too")
	# Simultaneous events queue instead of overwriting each other.
	P.banner_time = 0.0; P.banner_queue.clear()
	P.show_banner("A", "first"); P.show_banner("B", "second")
	check(P.banner_title == "A" and P.banner_queue.size() == 1, "a second banner waits its turn")
	P.tick(P.BANNER_TIME + 0.1)
	check(P.banner_title == "B", "the queued banner plays next")
	P.tick(P.BANNER_TIME + 0.1); P.banner_title = ""
	# --- Quest steps announce once ---------------------------------------------
	g.quest = false; P.steps_done.clear(); P._initialized_steps = false; P.update(g, 0.1)
	P.banner_title = ""; P.banner_time = 0.0; P.banner_queue.clear(); g.quest = true; P.update(g, 0.1)
	check(P.banner_title == "QUEST UPDATED" and P.banner_text.begins_with("Talk to Rowan"), "talking to Rowan announces a quest update")
	P.banner_title = ""; P.banner_time = 0.0; P.banner_queue.clear(); P.update(g, 0.1)
	check(P.banner_title == "" and P.banner_queue.is_empty(), "a finished step is announced only once")
	check(P.quest_steps(g).size() == 6, "journal lists six main-quest steps")
	# --- Journal / map keys ------------------------------------------------------
	g.map_open = false
	key(KEY_J); check(g.map_open and g.map_tab == "journal", "J opens the journal")
	key(KEY_M); check(g.map_open and g.map_tab == "map", "M switches to the map")
	key(KEY_M); check(not g.map_open, "M closes it")
	g.map_open = true; g.map_tab = "map"; g.activate_button("tab_journal"); check(g.map_tab == "journal", "Journal tab button works")
	g.activate_button("tab_map"); check(g.map_tab == "map", "Map tab button works")
	g.activate_button("map_close"); check(not g.map_open, "Close works from either tab")
	check(not P.next_gear_hint(g).is_empty(), "journal always suggests the next gear step")
	print("PROGRESSION_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
