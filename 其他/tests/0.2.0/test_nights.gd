extends SceneTree
# v0.2.0 Night Survival 2.0: event schedule, each event's real effect, night-4
# tier, wolf flanking and the Last Watch waves at the beacon.
var checks := 0
var failures: Array[String] = []
var g: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func fresh(seed: int = 164) -> void:
	if g != null: g.queue_free()
	g = load("res://main.tscn").instantiate(); g.resource_seed = seed; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear()
func force_event(name: String) -> void:
	g.night_events.current = name; g.phase = "night"; g.update_night_atmosphere()
func wolf_near(p: Vector2, r: float) -> Dictionary:
	for k in range(120):
		var q: Vector2 = p + Vector2.RIGHT.rotated(TAU * k / 29.0) * (r + (k % 5) * 12)
		var probe := {"species": "wolf", "facing": Vector2.DOWN, "uid": -9}
		if g.wildlife._walkable(g, probe, q):
			var a: Dictionary = g.wildlife._register_animal(g, "wolf", q, Vector2.DOWN)
			a.age = 30.0; return a
	return {}

func run() -> void:
	await fresh()
	var E: Variant = g.night_events
	# --- Schedule ----------------------------------------------------------------
	for seed in [1, 2, 3, 4, 5, 6]:
		E.setup(seed)
		var seq: Array = []
		for n in range(1, 9): seq.append(E.choose(n))
		check(seq[0] == "calm", "seed %d: night 1 is calm" % seed)
		check(E.SECOND_NIGHT.has(seq[1]), "seed %d: night 2 is howling, fog or bear (%s)" % [seed, seq[1]])
		var repeats := 0
		for i in range(1, seq.size()): if seq[i] == seq[i - 1]: repeats += 1
		check(repeats == 0, "seed %d: no event repeats on consecutive nights %s" % [seed, str(seq)])
		E.setup(seed); var again: Array = []
		for n in range(1, 9): again.append(E.choose(n))
		check(again == seq, "seed %d: schedule is reproducible" % seed)
	var blood := false
	for seed in range(1, 30):
		E.setup(seed); E.choose(1); E.choose(2)
		for n in range(3, 8): if E.choose(n) == "blood_moon": blood = true
	check(blood, "blood moon appears on later nights")
	# Dusk announces tonight's event.
	await fresh()
	g.phase = "day"; g.night = 2; g.progression.banner_time = 0.0; g.progression.banner_queue.clear()
	g.start_night()
	check(g.night_events.current != "calm" and g.progression.banner_title.begins_with("NIGHT 2"), "dusk of night 2 announces an event (%s)" % g.progression.banner_title)
	check(g.night_mod("missing", 7) == 7, "unknown modifiers fall back")
	g.phase = "day"; check(g.night_mod("extra_wolves", 0) == 0, "events do not apply in daylight")
	# --- Howling pack: one more wolf, eager trackers ------------------------
	await fresh(); g.night = 2; force_event("calm"); g.wildlife.period = "night"; g.wildlife._populate(g)
	var calm_wolves: int = g.wildlife.animals.filter(func(a): return a.species == "wolf").size()
	g.wildlife.animals.clear(); force_event("howling"); g.wildlife._populate(g)
	var pack: int = g.wildlife.animals.filter(func(a): return a.species == "wolf").size()
	check(pack == calm_wolves + 1, "howling pack adds a wolf (%d -> %d)" % [calm_wolves, pack])
	check(g.wildlife.night_hunt_chance(g) > 0.7, "howling pack wolves track the trail more eagerly")
	# --- Fog: darker, shorter sight, faster sanity loss ----------------------
	await fresh(); g.night = 2; g.phase = "night"; g.night_elapsed = 45.0; g.player = Vector2(1240, 760)
	force_event("calm"); var clear_light: float = g.lighting.sample(g, Vector2(1240, 760)); var calm_loss := 0.0
	g.sanity = 80.0; for i in range(10): g.survival.update(g, 0.1)
	calm_loss = 80.0 - g.sanity
	force_event("fog"); var fog_light: float = g.lighting.sample(g, Vector2(1240, 760))
	g.sanity = 80.0; for i in range(10): g.survival.update(g, 0.1)
	var fog_loss: float = 80.0 - g.sanity
	check(fog_light < clear_light, "fog makes the night darker (%.3f < %.3f)" % [fog_light, clear_light])
	check(fog_loss > calm_loss * 1.25, "fog drains sanity faster (%.3f vs %.3f)" % [fog_loss, calm_loss])
	check(is_equal_approx(float(g.night_mod("notice_mult", 1.0)), 0.75), "fog shortens predator sight")
	# --- Blood moon: red tint, shadows at 45 sanity -------------------------
	force_event("blood_moon")
	check(g.night_fog_color.r > g.night_fog_color.b, "blood moon tints the dark red")
	g.sanity = 40.0; g.survival.shadow_cooldown = 0; g.survival.shadow_retry = 0; g.torch_lit = false
	g.player = Vector2(1240, 760); g.wildlife.animals.clear()
	g.survival.update(g, 0.05)
	check(g.wildlife.has_shadow(), "under a blood moon a shadow can appear at 40 sanity")
	g.wildlife.dismiss_shadow(); force_event("calm"); g.survival.shadow_cooldown = 0; g.survival.shadow_retry = 0
	g.survival.update(g, 0.05)
	check(not g.wildlife.has_shadow(), "on a calm night 40 sanity is not low enough for a shadow")
	# --- Restless bear -----------------------------------------------------------
	force_event("bear"); g.wildlife.animals.clear(); g.wildlife.scent.clear(); g.wildlife.period = "night"
	for i in range(15): g.wildlife.scent.append(Vector2(1240, 760) + Vector2(i * 6, 0))
	var tracked := 0
	for i in range(20):
		var bear: Dictionary = g.wildlife._register_animal(g, "bear", Vector2(1700, 1100), Vector2.DOWN)
		var goal: Vector2 = g.wildlife._new_wander_goal(g, bear)
		if bear.get("hunting", false): tracked += 1
		g.wildlife.animals.erase(bear)
	check(tracked >= 13, "a restless bear tracks the trail most of the time (%d/20)" % tracked)
	# --- Night 4 tier ------------------------------------------------------------
	check(int(g.Balance.night_profile(4).wolves) == 4 and int(g.Balance.night_profile(9).wolves) == 4, "night 4 onward uses the hardest tier")
	# --- Flanking -----------------------------------------------------------------
	await fresh(); g.phase = "night"; g.night = 3; g.player = Vector2(1240, 760)
	var lead := wolf_near(g.player, 140.0); lead.state = "chase"
	var second := wolf_near(g.player, 230.0)
	var flank: Vector2 = load("res://predator_behavior.gd")._flank_goal(g.wildlife, g, second)
	check(flank.distance_to(g.player) > 60.0, "a second wolf swings to the side instead of queueing")
	g.wildlife.animals.erase(lead)
	check(load("res://predator_behavior.gd")._flank_goal(g.wildlife, g, second) == g.player, "a lone wolf goes straight for the player")
	# --- The Last Watch ----------------------------------------------------------
	await fresh(); g.phase = "night"; g.night = 3; g.night_elapsed = 5.0
	var b: Variant = g.beacon
	b.stage = "repaired"; b.lens_found = true; b.rune_open = true; b.core_taken = true
	var guard := Vector2.INF
	for r in [70.0, 82.0, 94.0, 106.0]:
		for k in range(36):
			var q: Vector2 = b.BEACON_POS + Vector2.RIGHT.rotated(TAU * k / 36.0) * r
			if guard == Vector2.INF and g.walkable(q):
				g.player = q
				if str(g.nearest_target().get("kind", "")) == "beacon": guard = q
	check(guard != Vector2.INF, "found a legal spot beside the beacon")
	g.player = guard; g.bag.add("log", 3); g.interaction_cooldown = 0; g.interact()
	check(b.stage == "igniting" and g.progression.banner_queue.any(func(x): return x[0] == "THE LAST WATCH") or g.progression.banner_title == "THE LAST WATCH", "lighting the beacon announces the Last Watch")
	g.wildlife.animals.clear()
	var wave_counts: Array = []
	var bear_seen := false
	var steps := 0
	while b.stage == "igniting" and steps < 2000:
		g.health = 100; g.player = guard
		b.update(g, 1.0 / 30.0); steps += 1
		var wolves: int = g.wildlife.animals.filter(func(a): return a.species == "wolf" and a.get("wave", false)).size()
		if wave_counts.is_empty() or wave_counts.back() != wolves: wave_counts.append(wolves)
		if g.wildlife.animals.any(func(a): return a.species == "bear" and a.get("wave", false)): bear_seen = true
	check(b.stage == "lit" and g.won, "the beacon can still be lit through the waves")
	check(wave_counts.size() >= 3 and wave_counts.back() >= 4, "three waves add wolves over the watch %s" % str(wave_counts))
	check(bear_seen, "on night 3 a bear joins the watch")
	for a in g.wildlife.animals:
		if not a.get("wave", false): continue
		check(a.home.distance_to(b.BEACON_POS) < 1.0, "wave hunters make for the beacon")
	print("NIGHTS_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
