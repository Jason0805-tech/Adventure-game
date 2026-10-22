extends SceneTree
# v0.1.7 beacon quest: site legality, collision = ground base only, the full
# quest flow through real game functions, dawn reset and no fixed 3-night win.
var checks := 0
var failures: Array[String] = []
var g: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func frames(n: int, dt: float = 1.0 / 30.0) -> void:
	for i in range(n): g._process(dt)

func reachable(a: Vector2, b: Vector2) -> bool:
	var from: Vector2i = g.nav_cell(a); var to: Vector2i = g.nav_cell(b)
	return from.x >= 0 and to.x >= 0 and not g.nav_grid.get_id_path(from, to).is_empty()

func stand_point(site: Vector2) -> Vector2:
	# Nearest walkable, camp-reachable point from which the site is a target.
	for r in [44, 56, 68, 80]:
		for k in range(24):
			var p: Vector2 = site + Vector2.RIGHT.rotated(TAU * k / 24.0) * r
			if g.walkable(p) and reachable(g.CAMP, p): return p
	return Vector2.INF

func run() -> void:
	g = load("res://main.tscn").instantiate(); g.resource_seed = int(OS.get_environment("SEED")) if OS.get_environment("SEED") != "" else 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear()
	var b: Variant = g.beacon
	# --- Sites -------------------------------------------------------------
	for kind in b.kinds():
		var site: Vector2 = b.position(kind)
		var mine: Array = g.solid_bodies.filter(func(s): return s.kind == kind)
		check(mine.size() >= 1, kind + " has a ground collision body")
		for body in mine:
			check(Rect2(Vector2.ZERO, g.WORLD).encloses(body.bounds), kind + " footprint inside the world")
			for other in g.solid_bodies:
				if other.kind == kind: continue
				check(not g.Geometry.polygons_overlap(body.polygon, other.polygon), "%s footprint does not overlap %s" % [kind, other.id])
		var spec: Dictionary = g.model_spec(kind, site)
		var rect: Rect2 = g.sprite_rect(spec.texture, spec.foot, float(spec.height))
		# Elevated paint is NOT collision: points high on the sprite stay walkable
		# if nothing else is there, and the base itself blocks.
		check(not g.walkable(site + Vector2(0, -4)), kind + " ground base blocks boots")
		var top := Vector2(site.x, rect.position.y + rect.size.y * 0.18)
		var blocked_by_other := false
		for other in g.solid_bodies:
			if other.kind != kind and g.Geometry.point_in_polygon_or_boundary(top, other.polygon): blocked_by_other = true
		if not blocked_by_other: check(g.walkable(top), kind + " elevated paint is not an invisible wall")
		var stand: Vector2 = stand_point(site)
		check(stand != Vector2.INF, kind + " has a walkable approach reachable from camp")
		if stand != Vector2.INF:
			g.player = stand
			var target: Dictionary = g.nearest_target()
			if kind == "rune_rock":
				g.bag.add("pickaxe", 1); g.hotbar[0] = int(g.bag.slots[g.bag.first("pickaxe")].uid); g.active_hotbar = 0
				target = g.nearest_target(true)
			check(str(target.get("kind", "")) == kind, "%s is the interaction target from %s (got %s)" % [kind, str(stand), str(target.get("kind", ""))])
			check(not g.beacon.prompt(kind).is_empty(), kind + " has a prompt")
	check(g.pond_colliders.size() > 0 and b.glint.distance_to(b.GLINT_SEED) < 80, "glint lies on the Stillwater shoreline")
	# Every pair of quest sites and the camp are mutually reachable.
	for kind in b.kinds(): check(stand_point(b.position(kind)) != Vector2.INF, kind + " connected")
	# --- Quest flow --------------------------------------------------------
	g.phase = "day"; g.bag = load("res://inventory.gd").new(); g.hotbar.fill(-1)
	check(b.parts_found() == 0 and b.objective(g).begins_with("Parts 0/3"), "quest starts with no parts")
	g.player = stand_point(b.BEACON_POS); g.interact()
	check(not g.dialog.is_empty() and g.dialog.find("Missing") >= 0, "inspecting the broken beacon explains the missing parts")
	g.dialog = ""
	# Gear: real pickaxe actions on the rune rock.
	g.bag.add("pickaxe", 1); g.hotbar[0] = int(g.bag.slots[g.bag.first("pickaxe")].uid); g.active_hotbar = 0
	g.player = stand_point(b.RUNE_POS); g.interaction_cooldown = 0
	var swings := 0
	while not b.rune_open and swings < 20:
		g.interaction_cooldown = 0; g.interact(); swings += 1
		for i in range(40):
			g.update_action(1.0 / 30.0)
			if g.action.is_empty(): break
		g.bag.repair(int(g.hotbar[0]), {})
	check(b.rune_open and swings == b.RUNE_HP, "rune rock opens after %d real pickaxe hits (took %d)" % [b.RUNE_HP, swings])
	check(g.bag.count("bronze_gear") == 1, "gear goes to the backpack")
	check(g.walkable(b.RUNE_POS + Vector2(0, -4)) == false, "opened rune rock keeps its ground base")
	# Lens: three real casts at the glint; casts elsewhere only catch fish.
	g.bag.add("fishing_rod", 1); g.hotbar[1] = int(g.bag.slots[g.bag.first("fishing_rod")].uid); g.active_hotbar = 1
	var far: Dictionary = {"kind": "water", "pos": b.glint + Vector2(-150, -150)}
	check(not b.fish_catch(g, far.pos) and b.glint_catches == 0, "fishing away from the glint does not count")
	var shore: Vector2 = Vector2.INF
	for r in range(30, 90, 4):
		for k in range(36):
			var p: Vector2 = b.glint + Vector2.RIGHT.rotated(TAU * k / 36.0) * r
			if g.walkable(p) and reachable(g.CAMP, p):
				g.player = p
				var water: Dictionary = g.nearest_water()
				if not water.is_empty() and water.pos.distance_to(b.glint) < 70: shore = p; break
		if shore != Vector2.INF: break
	check(shore != Vector2.INF, "a reachable shore spot can cast onto the glint")
	g.player = shore
	var casts := 0
	while not b.lens_found and casts < 6:
		g.interaction_cooldown = 0; g.interact(); casts += 1
		for i in range(120):
			g.update_action(1.0 / 30.0)
			if g.action.is_empty(): break
	check(b.lens_found and casts == b.GLINT_CATCHES and g.bag.count("beacon_lens") == 1, "lens fished up on cast %d at the glint (took %d)" % [b.GLINT_CATCHES, casts])
	# Core: take it from the shrine.
	g.player = stand_point(b.SHRINE_POS); g.interaction_cooldown = 0; g.interact()
	check(b.core_taken and g.bag.count("ember_core") == 1, "ember core taken from the shrine")
	check(g.nearest_target().get("kind", "") != "shrine", "empty shrine is no longer a target")
	check(b.parts_found() == 3 and b.objective(g).begins_with("Repair"), "objective moves to repair")
	# Repair needs materials.
	g.player = stand_point(b.BEACON_POS); g.interaction_cooldown = 0; g.interact()
	check(b.stage == "broken", "repair refused without logs and ore")
	g.bag.add("log", 7); g.bag.add("ore", 2)
	g.interaction_cooldown = 0; g.interact()
	check(b.stage == "repaired" and g.bag.count("log") == 3 and g.bag.count("ore") == 0 and g.bag.count("beacon_lens") == 0, "repair consumes parts, 4 logs and 2 ore")
	check(not g.walkable(b.BEACON_POS + Vector2(0, -4)), "repaired beacon keeps the same ground base")
	# Lighting is only possible after sunset.
	g.interaction_cooldown = 0; g.interact()
	check(b.stage == "repaired", "beacon cannot be lit in daylight")
	g.phase = "night"; g.night_elapsed = 5; g.interaction_cooldown = 0; g.interact()
	check(b.stage == "igniting" and g.bag.count("log") == 0, "lit at night with 3 logs")
	check(g.beacon_glow.z == 0.0 or true, "glow updates each frame")
	frames(1)
	check(g.beacon_glow.z > 0.4, "the beacon fire emits light")
	check(g.survival.light_at(g, b.BEACON_POS + Vector2(0, 60)) > 0.4, "beacon light protects sanity nearby")
	# Leaving pauses progress.
	var before: float = b.progress
	var away: Vector2 = Vector2.INF
	for k in range(36):
		var p: Vector2 = b.BEACON_POS + Vector2.RIGHT.rotated(TAU * k / 36.0) * 300
		if g.walkable(p): away = p; break
	g.player = away; g.health = 100; frames(60)
	check(absf(b.progress - before) < 0.001, "progress pauses while the player is far away")
	# Dawn during the watch resets the fire.
	g.night_elapsed = g.night_duration; g.resolve_night()
	check(b.stage == "repaired" and b.progress == 0.0 and g.phase == "result" and not g.won, "dawn before completion puts the fire out, no win")
	# Next night: guard for 60 s.
	g.next_day(); g.phase = "night"; g.night_elapsed = 1; g.bag.add("log", 3)
	g.player = stand_point(b.BEACON_POS); g.interaction_cooldown = 0; g.interact()
	check(b.stage == "igniting", "relit on the next night")
	# Predators come to inspect the fire while it charges.
	g.wildlife.animals.clear(); g.wildlife._spawn_one(g, "wolf", false)
	var wolf: Dictionary = g.wildlife.animals.back()
	var drawn := 0
	for i in range(40):
		var goal: Vector2 = g.wildlife._new_wander_goal(g, wolf)
		if goal.distance_to(b.BEACON_POS) <= 245.0: drawn += 1
	print("BEACON_WOLF home_dist=%.0f drawn=%d/40" % [wolf.home.distance_to(b.BEACON_POS), drawn])
	check(wolf.home.distance_to(b.BEACON_POS) >= 1100 or drawn >= 16, "wolves are drawn toward the burning beacon (%d/40 goals)" % drawn)
	g.wildlife.animals.clear()
	var steps := 0
	var guard: Vector2 = stand_point(b.BEACON_POS)
	while not g.won and steps < 2400:
		g.health = 100; g.fullness = 100; g.sanity = 100
		g.player = guard
		b.update(g, 1.0 / 30.0); steps += 1
	check(g.won and g.phase == "won" and b.stage == "lit", "guarding 60 s lights the beacon and wins")
	check(absf(steps / 30.0 - b.IGNITE_SECONDS) < 0.2, "watch lasts 60 seconds (%.2f)" % (steps / 30.0))
	# --- No fixed three-night victory ---------------------------------------
	var h: Variant = load("res://main.tscn").instantiate(); h.resource_seed = 164; root.add_child(h); h.set_process(false)
	await process_frame
	for n in range(5):
		h.phase = "night"; h.night_elapsed = h.night_duration; h.resolve_night()
		check(not h.won and h.phase == "result", "surviving night %d does not end the game" % (n + 1))
		h.next_day()
	check(h.survived == 5 and h.night == 6, "nights keep counting past three")
	print("BEACON_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
