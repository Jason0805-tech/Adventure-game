extends SceneTree
# Night-encounter benchmark (works on any version): a bot walks a fixed tour of
# the map at 108 units/s during a full 90 s night, or stands still in the open.
# It never fights back and is kept alive, so we measure how often predators
# actually find and engage the player. Reported per night 1-3, three seeds.
const ROUTE := [Vector2(700, 760), Vector2(1085, 640), Vector2(1450, 620), Vector2(1700, 400), Vector2(1880, 520), Vector2(1700, 1000), Vector2(1580, 1300), Vector2(1100, 1150), Vector2(700, 1000), Vector2(450, 760)]
var g: Variant

func _initialize() -> void: call_deferred("run")

func path_to(a: Vector2, b: Vector2) -> PackedVector2Array:
	var from: Vector2i = g.nav_cell(a); var to: Vector2i = g.nav_cell(b)
	if from.x < 0 or to.x < 0: return PackedVector2Array([b])
	var cells: Array = g.nav_grid.get_id_path(from, to)
	var pts := PackedVector2Array()
	for c in cells: pts.append(g.nav_grid.get_point_position(c))
	pts.append(b)
	return pts

func engaged(a: Dictionary) -> bool:
	return str(a.state) in ["chase", "windup", "charge_warn", "charge"]

func night_run(seed: int, night: int, moving: bool) -> Dictionary:
	g = load("res://main.tscn").instantiate(); g.resource_seed = seed; root.add_child(g); g.set_process(false)
	await process_frame
	g.player = Vector2(1240, 760) if not moving else Vector2(560, 770)
	g.night = night; g.phase = "night"; g.night_elapsed = 0.0; g.phase_time = 0.0
	g.wildlife.animals.clear(); g.wildlife.period = ""
	var route_i := 0
	var path := path_to(g.player, ROUTE[0])
	var cursor := 0
	var t := 0.0
	var first := -1.0
	var engaged_time := 0.0
	var engagements := 0
	var was_engaged := false
	var hits := 0
	var near_time := 0.0
	var dt := 0.1
	while t < 90.0:
		g.health = 100; g.fullness = 100; g.sanity = 100
		if moving:
			var step := 108.0 * dt
			while step > 0.0 and cursor < path.size():
				var to: Vector2 = path[cursor]
				var d: float = g.player.distance_to(to)
				if d <= step: g.player = to; step -= d; cursor += 1
				else: g.facing = (to - g.player).normalized(); g.player += g.facing * step; step = 0.0
			if cursor >= path.size():
				route_i = (route_i + 1) % ROUTE.size()
				path = path_to(g.player, ROUTE[route_i]); cursor = 0
		g.update_wildlife(dt)
		if g.has_method("update_world_events"): g.update_world_events(dt)
		var any := false
		var near := false
		for a in g.wildlife.animals:
			if not g.wildlife.Data.info(a.species).get("predator", false): continue
			if engaged(a): any = true
			if a.p.distance_to(g.player) < 320.0: near = true
		for e in g.wildlife.last_events:
			if e.get("type", "") == "player_hit": hits += 1
		if any:
			engaged_time += dt
			if first < 0.0: first = t
			if not was_engaged: engagements += 1
		if near: near_time += dt
		was_engaged = any
		g.night_elapsed = t; t += dt
	g.queue_free()
	return {"first": first, "engaged_s": engaged_time, "engagements": engagements, "near_s": near_time, "hits": hits}

func run() -> void:
	var report := {}
	for mode in ["moving", "standing"]:
		for night in [1, 2, 3]:
			var rows := []
			for seed in [11, 23, 37]:
				rows.append(await night_run(seed, night, mode == "moving"))
			var first_sum := 0.0; var firsts := 0; var eng := 0.0; var count := 0.0; var near := 0.0; var hits := 0.0; var none := 0
			for r in rows:
				if r.first >= 0: first_sum += r.first; firsts += 1
				else: none += 1
				eng += r.engaged_s; count += r.engagements; near += r.near_s; hits += r.hits
			report["%s_night%d" % [mode, night]] = {"avg_first_contact_s": snappedf(first_sum / maxf(1, firsts), 0.1), "nights_without_contact": none, "avg_engagements": snappedf(count / 3.0, 0.1), "avg_engaged_s": snappedf(eng / 3.0, 0.1), "avg_predator_within_320_s": snappedf(near / 3.0, 0.1), "avg_hits_taken": snappedf(hits / 3.0, 0.1)}
	print("ENCOUNTERS ", JSON.stringify(report))
	quit()
