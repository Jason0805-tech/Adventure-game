extends SceneTree
# v0.3.0 smoke test: the expanded world builds, reports its contents and the
# time each startup step takes, and draws a few frames without errors.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var t0 := Time.get_ticks_msec()
	var g: Variant = load("res://main.tscn").instantiate()
	g.resource_seed = 164
	root.add_child(g)
	await process_frame
	var t1 := Time.get_ticks_msec()
	var R: Variant = g.Regions
	var per := {"forest": 0, "valley": 0, "ruins": 0}
	for t in g.trees: per[R.region_at(t)] += 1
	var items := {}
	for it in g.items:
		var key: String = "%s/%s" % [it.kind, R.region_at(it.pos)]
		items[key] = int(items.get(key, 0)) + 1
	var rubble: int = g.ore_veins.filter(func(v): return v.get("kind", "") == "rubble").size()
	var started := Time.get_ticks_usec()
	for i in range(200): g.static_walkable(Vector2(2600 + i, 900))
	var walk_us: float = (Time.get_ticks_usec() - started) / 200.0
	started = Time.get_ticks_usec()
	g.rebuild_navigation()
	var nav_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	g.paint_entries(true)
	var paint_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	print("BOOT ", JSON.stringify({"startup_ms": t1 - t0, "trees": per, "props": g.props.size(), "rubble": rubble, "bodies": g.solid_bodies.size(), "items": items, "walkable_us": snappedf(walk_us, 0.1), "nav_rebuild_ms": snappedf(nav_ms, 0.1), "paint_entries_ms": snappedf(paint_ms, 0.1), "glint": g.beacon.glint}))
	started = Time.get_ticks_usec()
	g.ground_layer.setup(g.paint_density.prepare_rect(g.meadow, R.FOREST.size), g.WORLD)
	var ground_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	g.build_world()
	var world_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	started = Time.get_ticks_usec()
	g.load_art()
	var art_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	print("BOOT_PARTS ", JSON.stringify({"ground_ms": snappedf(ground_ms, 1), "build_world_ms": snappedf(world_ms, 1), "load_art_ms": snappedf(art_ms, 1)}))
	for i in range(5): await process_frame
	print("BOOT_DONE")
	quit()
