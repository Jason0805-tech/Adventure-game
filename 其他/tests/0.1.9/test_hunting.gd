extends SceneTree
# v0.1.9 wildlife AI: scent trail (old positions only), noise investigation,
# torch lure, near-player night spawns, far-hunter recycling, deer herd alarm.
var checks := 0
var failures: Array[String] = []
var g: Variant
var W: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func wolf_at(p: Vector2) -> Dictionary:
	var a: Dictionary = W._register_animal(g, "wolf", p, Vector2.DOWN)
	a.age = 30.0; a.state = "idle"; a.timer = 5.0
	return a
func open_point(center: Vector2, r_min: float, r_max: float) -> Vector2:
	for k in range(200):
		var p: Vector2 = center + Vector2.RIGHT.rotated(TAU * k / 37.0) * lerpf(r_min, r_max, float(k % 7) / 6.0)
		if g.walkable(p) and W._walkable(g, {"species": "wolf", "facing": Vector2.DOWN, "uid": -5}, p): return p
	return Vector2.INF

func run() -> void:
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	W = g.wildlife
	g.phase = "night"; g.night = 2; g.night_elapsed = 0.0
	W.animals.clear(); W.period = "night"; W.respawn_in = 999.0
	# --- Scent trail ------------------------------------------------------------
	g.player = Vector2(1240, 760)
	for i in range(30):
		g.player = Vector2(1000 + i * 10, 760)
		W.update(g, 0.1, "night"); W.scent_in = 0.0; W.update(g, 0.1, "night")
	check(W.scent.size() >= 20, "night records a scent trail (%d points)" % W.scent.size())
	var old: Vector2 = W.scent_point(10.0, 28.0)
	check(old != Vector2.INF and old.distance_to(g.player) > 40.0, "trail points are old positions, not the live player")
	# Trail following: unaware wolves head for old trail points.
	var trail_goals := 0
	for i in range(30):
		var w := wolf_at(open_point(Vector2(1400, 700), 300, 500))
		var goal: Vector2 = W._new_wander_goal(g, w)
		var near_trail := false
		for s in W.scent: if goal.distance_to(s) < 80.0: near_trail = true
		if near_trail and w.get("hunting", false): trail_goals += 1
		W.animals.erase(w)
	check(trail_goals >= 7 and trail_goals <= 23, "night 2: roughly 45%% of new goals follow the trail (%d/30)" % trail_goals)
	W.update(g, 0.1, "day"); check(W.scent.is_empty(), "daylight clears the scent trail")
	W.period = "night"
	# --- Noise ----------------------------------------------------------------------
	W.animals.clear()
	var listener := wolf_at(open_point(Vector2(1240, 760), 250, 380))
	var deaf := wolf_at(open_point(Vector2(1240, 760), 700, 900))
	var drawn: int = W.make_noise(g, Vector2(1240, 760), 420.0, "tree")
	check(drawn == 1 and listener.state == "investigate" and listener.goal.distance_to(Vector2(1240, 760)) < 1.0, "a wolf in earshot investigates the noise")
	check(deaf.state != "investigate", "a wolf beyond earshot ignores it")
	W._register_animal(g, "rabbit", Vector2(1260, 780), Vector2.DOWN)
	W.make_noise(g, Vector2(1240, 760), 420.0)
	check(W.animals.back().state != "investigate", "prey animals are not drawn by noise")
	# Real actions make noise.
	W.animals.clear()
	var w2 := wolf_at(open_point(Vector2(1240, 760), 200, 330))
	var tree: Vector2 = Vector2.INF
	for t in g.trees:
		if g.tree_live(t) and t.distance_to(w2.p) < 380.0: tree = t; break
	if tree != Vector2.INF:
		g.player = tree + Vector2(0, 40)
		g.bag.add("stone_axe", 1); g.hotbar[0] = int(g.bag.slots[g.bag.first("stone_axe")].uid); g.active_hotbar = 0
		g.action = {"target": {"kind": "tree", "pos": tree}, "uid": g.hotbar[0], "id": "stone_axe", "elapsed": 0.0, "duration": 0.8, "hit": false}
		g.commit_action()
		check(w2.state == "investigate" and w2.goal.distance_to(tree) < 1.0, "chopping a tree at night draws a nearby wolf")
	else:
		check(false, "found a tree near the test wolf")
	W.animals.clear(); W.noises.clear()
	g.player = open_point(Vector2(1240, 760), 0, 60); g.stamina = 100.0; g.stamina_exhausted = false; g.sprint_noise_in = 0.0
	var e := InputEventKey.new(); e.physical_keycode = KEY_SHIFT; e.pressed = true; Input.parse_input_event(e); Input.flush_buffered_events()
	g.update_stamina(Vector2.RIGHT, 0.1)
	e = InputEventKey.new(); e.physical_keycode = KEY_SHIFT; e.pressed = false; Input.parse_input_event(e); Input.flush_buffered_events()
	check(not W.noises.is_empty() and W.noises.back().kind == "footsteps", "sprinting makes footstep noise")
	# --- Torch lure ---------------------------------------------------------------
	W.animals.clear(); g.player = Vector2(1240, 760); g.torch_lit = true; g.torch_fuel = 60.0
	var lured := 0
	for i in range(30):
		var w := wolf_at(open_point(g.player, 320, 520))
		var goal: Vector2 = W._new_wander_goal(g, w)
		if goal.distance_to(g.player) < 260.0: lured += 1
		W.animals.erase(w)
	check(lured >= 10, "a lit torch draws curious wolves toward its light (%d/30)" % lured)
	g.torch_lit = false
	# --- Near-player night spawns -----------------------------------------------
	W.animals.clear()
	for p in [Vector2(1240, 760), Vector2(700, 1150), Vector2(1800, 1150)]:
		g.player = p
		var ok := 0; var too_close := 0
		for i in range(12):
			if W._spawn_one(g, "wolf", false):
				var d: float = W.animals.back().p.distance_to(p)
				if d < 360.0: too_close += 1
				if d < 900.0: ok += 1
				W.animals.pop_back()
		check(too_close == 0, "night spawns never appear within 360 of the player at %s" % str(p))
		check(ok >= 8, "night spawns arrive near the player's area at %s (%d/12)" % [str(p), ok])
	# --- Far hunters recycle -------------------------------------------------------
	W.animals.clear(); g.player = Vector2(300, 1300)
	var far := wolf_at(open_point(Vector2(1950, 300), 0, 200))
	far.state = "wander"
	for i in range(250): W._recycle_far_hunters(g, 0.1)
	check(not W.animals.has(far), "a predator idling far away slips off after ~22 s")
	# --- Deer herd ------------------------------------------------------------------
	g.phase = "day"; W.period = "day"; W.animals.clear(); g.player = Vector2(1000, 1100)
	var d1: Dictionary = W._register_animal(g, "deer", open_point(Vector2(1000, 1100), 120, 160), Vector2.DOWN)
	var d2: Dictionary = W._register_animal(g, "deer", open_point(d1.p, 60, 150), Vector2.DOWN)
	var d3: Dictionary = W._register_animal(g, "deer", open_point(Vector2(1000, 1100), 600, 800), Vector2.DOWN)
	for d in [d1, d2, d3]: d.age = 30.0; d.state = "idle"; d.timer = 5.0
	W._update_animal(g, d1, 0.1)
	check(d1.state == "flee" and d2.state == "flee", "one startled deer alarms its neighbour")
	check(d3.state != "flee", "deer far away keep grazing")
	print("HUNTING_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
