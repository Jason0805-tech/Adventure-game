extends SceneTree
# v0.1.7-alpha.1 feedback fixes: shorter day, sprint + stamina, button press
# feedback, stone gate removed, balanced/relocating resources, world map.
var checks := 0
var failures: Array[String] = []
var g: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new(); e.physical_keycode = code; e.keycode = code; e.pressed = pressed
	Input.parse_input_event(e); Input.flush_buffered_events()
func open_spot(from: Vector2) -> Vector2:
	# A start point with a clear straight run to the right.
	for r in range(0, 600, 20):
		for k in range(12):
			var p: Vector2 = from + Vector2.RIGHT.rotated(TAU * k / 12.0) * r
			var clear := true
			for s in range(0, 260, 12):
				if not g.walkable(p + Vector2(s, 0)): clear = false; break
			if clear: return p
	return from
func run_for(seconds: float, shift: bool) -> float:
	var start: Vector2 = g.player
	if shift: key(KEY_SHIFT, true)
	key(KEY_D, true)
	var t := 0.0
	while t < seconds: g._process(1.0 / 30.0); t += 1.0 / 30.0
	key(KEY_D, false)
	if shift: key(KEY_SHIFT, false)
	return g.player.distance_to(start)
func zone_counts(kind: String) -> Array:
	# v0.3.0 copy: the forest keeps its 3 x 3 zones (zones 0-8); the valley and
	# ruins have their own supplies, counted in test_regions.gd.
	var counts := []; counts.resize(9); counts.fill(0)
	for it in g.items:
		if it.kind == kind and not it.taken and not it.get("dropped", false) and g.Regions.FOREST.has_point(it.pos): counts[g.resource_zone(it.pos)] += 1
	return counts

func run() -> void:
	Input.use_accumulated_input = false
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear()
	# --- Day length ---------------------------------------------------------
	check(is_equal_approx(g.day_duration, 120.0), "daylight is 120 s")
	# --- Stone gate removed --------------------------------------------------
	check(g.solid_bodies.filter(func(b): return b.kind == "gate").is_empty(), "no gate collision body")
	check(g.scenery_entries().filter(func(e): return e.kind == "gate").is_empty(), "no gate painted")
	g.player = g.gate + Vector2(0, 80)
	check(str(g.nearest_target().get("kind", "")) != "gate", "gate is not an interaction target")
	check(g.walkable(g.gate + Vector2(0, 30)), "former gate pillar ground is walkable")
	# --- Sprint + stamina ----------------------------------------------------
	g.phase = "day"; g.fullness = 100; g.health = 100
	g.player = open_spot(Vector2(1000, 760)); g.stamina = 100.0
	var walk: float = run_for(1.0, false)
	g.player = open_spot(Vector2(1000, 760)); g.stamina = 100.0; g.stamina_exhausted = false
	var dash: float = run_for(1.0, true)
	check(walk > 90 and walk < 125, "walking covers ~108 units/s (%.0f)" % walk)
	check(dash > walk * 1.4, "sprint is clearly faster (%.0f vs %.0f)" % [dash, walk])
	check(g.stamina < 80 and g.stamina > 70, "one second of sprint uses ~25 stamina (%.1f)" % g.stamina)
	g.stamina = 100.0; g.stamina_exhausted = false
	var sprint_time := 0.0
	key(KEY_SHIFT, true); key(KEY_D, true)
	while not g.stamina_exhausted and sprint_time < 10.0:
		g.player = open_spot(g.player); g._process(1.0 / 30.0); sprint_time += 1.0 / 30.0
	key(KEY_D, false); key(KEY_SHIFT, false)
	check(sprint_time >= 3.0 and sprint_time <= 5.0, "full stamina lasts 3-5 s (%.2f s)" % sprint_time)
	check(g.stamina_exhausted and not g.sprinting, "empty stamina stops the sprint")
	key(KEY_SHIFT, true); key(KEY_D, true); g._process(1.0 / 30.0)
	check(not g.sprinting, "cannot sprint again while out of breath")
	key(KEY_D, false); key(KEY_SHIFT, false)
	var rest := 0.0
	while g.stamina_exhausted and rest < 10.0: g._process(1.0 / 30.0); rest += 1.0 / 30.0
	check(not g.stamina_exhausted and rest < 3.0, "breath recovers within ~2.2 s (%.2f s)" % rest)
	for i in range(240): g._process(1.0 / 30.0)
	check(is_equal_approx(g.stamina, 100.0), "stamina refills while resting")
	g.inventory = true; var held: float = g.stamina; g.stamina = 50.0; g._process(1.0); check(is_equal_approx(g.stamina, 50.0), "menus pause stamina too"); g.inventory = false; g.stamina = held
	g.mobile_action("sprint"); check(g.mobile_sprint, "mobile Run button turns sprint on")
	for i in range(10): g.update_stamina(Vector2.ZERO, 1.0 / 30.0)
	check(g.mobile_sprint, "Run stays armed while standing still")
	g.update_stamina(Vector2.RIGHT, 1.0 / 30.0); check(g.sprinting, "armed Run sprints once the stick moves")
	g.update_stamina(Vector2.ZERO, 1.0 / 30.0); check(not g.mobile_sprint, "stopping after a run disarms it")
	g.mobile_action("sprint")
	g.mobile_action("sprint"); check(not g.mobile_sprint, "tapping Run again turns it off")
	# --- Press feedback ------------------------------------------------------
	g.activate_button("next_page")
	check(g.press_scale("next_page") < 0.9, "a pressed button squashes")
	var r := Rect2(100, 100, 200, 50)
	check(g.pressed_rect(r, "next_page").get_center().is_equal_approx(r.get_center()), "squash keeps the button centred")
	for i in range(10): g.update_press_feedback(0.05)
	check(is_equal_approx(g.press_scale("next_page"), 1.0), "button springs back to full size")
	g.active_hotbar = 3; g.update_press_feedback(0.0)
	check(g.press_scale("select_3") < 0.95, "changing the hotbar slot pulses that slot")
	# --- Balanced resources --------------------------------------------------
	var worst := 0.0
	for seed in [7, 164, 9001, 31337]:
		var h: Variant = load("res://main.tscn").instantiate(); h.resource_seed = seed; root.add_child(h); h.set_process(false)
		await process_frame
		g = h
		for kind in ["branch", "rock", "rope", "berry"]:
			var counts := zone_counts(kind)
			var total := 0
			for c in counts: total += c
			check(total == {"branch": 22, "rock": 18, "rope": 18, "berry": 9}[kind], "seed %d places every %s (%d)" % [seed, kind, total])
			var share: float = float(counts.max()) / maxf(1, total)
			worst = maxf(worst, share)
			check(share <= 0.30, "seed %d: no zone holds more than 30%% of %s (%s)" % [seed, kind, str(counts)])
		var occupied := 0
		for c in zone_counts("branch"): if c > 0: occupied += 1
		check(occupied >= 7, "seed %d: branches reach at least 7 of 9 zones" % seed)
		h.queue_free()
	print("ALPHA1_BALANCE worst_zone_share=%.2f" % worst)
	g = load("res://main.tscn").instantiate(); g.resource_seed = 164; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear()
	# Collect half of everything, then a new morning moves them elsewhere.
	var before_total: int = g.items.size()
	var collected: Array = []
	for i in range(g.items.size()):
		if i % 2 == 0: g.items[i].taken = true; collected.append(g.items[i].pos)
	g.phase = "night"; g.night_elapsed = g.night_duration; g.resolve_night(); g.next_day()
	check(g.items.size() == before_total, "every collected node regrows the next morning (%d/%d)" % [g.items.size(), before_total])
	var same := 0
	for it in g.items:
		if collected.has(it.pos): same += 1
	check(same == 0, "regrown nodes appear in new places (%d reused)" % same)
	for kind in ["branch", "rock", "rope"]:
		check(float(zone_counts(kind).max()) / maxf(1, g.items.filter(func(it): return it.kind == kind and not it.taken and g.Regions.FOREST.has_point(it.pos)).size()) <= 0.30, "after regrowth %s stays balanced" % kind)
	var actors_clear := true
	for it in g.items:
		if it.pos.distance_to(g.player) < 60: actors_clear = false
	check(actors_clear, "nothing regrows under the player")
	# --- Map -----------------------------------------------------------------
	var m: Variant = g.map_view
	check(m.seen(g.CAMP) and not m.seen(g.beacon.BEACON_POS) and not m.seen(g.beacon.SHRINE_POS), "start: camp known, far places under fog")
	var p0: int = m.percent()
	m.reveal(g.beacon.BEACON_POS)
	check(m.seen(g.beacon.BEACON_POS) and m.percent() > p0, "walking near the beacon reveals it on the map")
	check(not m.seen(Vector2(100, 1400)), "unvisited corner stays hidden")
	g.phase = "day"; g.map_open = false
	key(KEY_M, true); key(KEY_M, false)
	check(g.map_open, "M opens the map")
	g._process(1.0 / 30.0)
	check(g.map_open and g.simulation_running(), "the world keeps running while the map is open")
	key(KEY_M, true); key(KEY_M, false)
	check(not g.map_open, "M closes the map")
	g.map_open = true; key(KEY_ESCAPE, true); key(KEY_ESCAPE, false)
	check(not g.map_open and not g.paused, "Esc closes the map without pausing")
	g.map_open = true; g.inventory = true; g._process(1.0 / 30.0)
	check(not g.map_open, "opening the backpack closes the map"); g.inventory = false
	g.mobile_action("map"); check(g.map_open, "mobile Map button opens the map")
	g.activate_button("map_close"); check(not g.map_open, "map Close button closes it")
	var regions: Dictionary = g.mobile.layout_for_size(Vector2(1334, 750)).regions
	var names := regions.keys()
	var overlap := false
	for i in range(names.size()):
		for j in range(i + 1, names.size()):
			if Rect2(regions[names[i]]).intersects(Rect2(regions[names[j]])): overlap = true; print("OVERLAP ", names[i], " ", names[j])
	check(not overlap, "mobile buttons (including Map and Run) never overlap")
	# A real touch on the Run button (mobile layout) arms sprint.
	root.size = Vector2i(1334, 750); await process_frame  # landscape phone canvas
	g.mobile.enabled = true; g.mobile_sprint = false; g.phase = "day"; g.dialog = ""; g.inventory = false; g.crafting = false; g.map_open = false
	g.mobile._prepare(g)
	var run_center: Vector2 = Rect2(g.mobile.hit_regions["sprint"]).get_center()
	var touch := InputEventScreenTouch.new(); touch.index = 3; touch.position = run_center; touch.pressed = true
	g._input(touch)
	var lift := InputEventScreenTouch.new(); lift.index = 3; lift.position = run_center; lift.pressed = false
	g._input(lift)
	check(g.mobile_sprint, "touching the Run button arms sprint")
	check(g.press_scale("m_sprint") < 0.95, "the Run button squashes when touched")
	g.mobile.enabled = false; g.mobile_sprint = false
	print("ALPHA1_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
