extends SceneTree

const OUT := "res://../../tests/0.1.5.9/"
const ITERATIONS := 100

func stats(microseconds: Array[float]) -> Dictionary:
	var ordered: Array[float] = microseconds.duplicate()
	ordered.sort()
	var total := 0.0
	for elapsed in ordered: total += elapsed
	return {"iterations": ordered.size(), "mean_ms": total / ordered.size() / 1000.0, "median_ms": ordered[ordered.size() / 2] / 1000.0, "p95_ms": ordered[int(ceil(ordered.size() * 0.95)) - 1] / 1000.0, "minimum_ms": ordered[0] / 1000.0, "maximum_ms": ordered[-1] / 1000.0}

func measure_entries(game: Variant, visible_only: bool) -> Dictionary:
	for i in range(5): game.paint_entries(visible_only)
	var values: Array[float] = []
	var entries: Array[Dictionary] = []
	for i in range(ITERATIONS):
		var start := Time.get_ticks_usec()
		entries = game.paint_entries(visible_only)
		values.append(float(Time.get_ticks_usec() - start))
	var result := stats(values)
	var kinds: Dictionary = {}
	for entry in entries: kinds[entry.kind] = int(kinds.get(entry.kind, 0)) + 1
	result["entry_count"] = entries.size()
	result["entry_kinds"] = kinds
	return result

func command_counts(game: Variant) -> Dictionary:
	game.reset_capture(); game._draw() # Warm source-image file cache, excluded.
	game.reset_capture(); game._draw()
	var kinds: Dictionary = {}
	for command in game.commands: kinds[command.kind] = int(kinds.get(command.kind, 0)) + 1
	var values: Array[float] = []
	for i in range(ITERATIONS):
		game.reset_capture()
		var start := Time.get_ticks_usec()
		game._draw()
		values.append(float(Time.get_ticks_usec() - start))
	return {"recorded_canvas_command_count": game.commands.size(), "command_kinds": kinds, "instrumented_command_assembly_cpu": stats(values), "timing_scope": "Whole _draw plus recording dictionaries, metadata lookups and ground command assembly; cached texture files. No GPU rendering or display. This is not a runtime frame time or FPS measurement."}

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game: Variant = load("res://main.gd").new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	var capture: Variant = load(OUT + "snapshot_game.gd").new()
	capture.resource_seed = 159
	root.add_child(capture)
	capture.set_process(false)
	capture.day_time = 30
	capture.show_collision = false
	capture.message_time = 0
	var fixtures := [{"name": "camp", "camera": Vector2(0, 250), "player": Vector2(360, 760)}, {"name": "forest", "camera": Vector2(1050, 650), "player": Vector2(1550, 1100)}, {"name": "pond", "camera": Vector2(650, 200), "player": Vector2(1000, 625)}]
	var results: Array = []
	for fixture in fixtures:
		game.camera = fixture.camera; game.player = fixture.player
		capture.camera = fixture.camera; capture.player = fixture.player
		var cache_before: int = game.depth_layers.band_cache.size()
		var result := {"scene": fixture.name, "camera": [fixture.camera.x, fixture.camera.y], "player": [fixture.player.x, fixture.player.y], "visible_entries": measure_entries(game, true), "full_world_entries": measure_entries(game, false), "canvas_commands": command_counts(capture), "band_cache_before": cache_before, "band_cache_after": game.depth_layers.band_cache.size()}
		results.append(result)
		print("DEPTH_CPU_BENCH ", fixture.name, " visible entries=", result.visible_entries.entry_count, " mean_ms=", result.visible_entries.mean_ms, " full entries=", result.full_world_entries.entry_count, " mean_ms=", result.full_world_entries.mean_ms, " commands=", result.canvas_commands.recorded_canvas_command_count)
	var report := {"version": "0.1.5.9", "iterations_per_case": ITERATIONS, "godot": Engine.get_version_info(), "viewport": [game.get_viewport_rect().size.x, game.get_viewport_rect().size.y], "scope": "Cached CPU paint-entry construction/sort in unmodified runtime and separate recorded Canvas command counts. No renderer/GPU FPS claim. Single local run under headless Godot; timing can vary with concurrent jobs.", "scenes": results}
	var file := FileAccess.open(OUT + "depth-cpu-benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	game.queue_free(); capture.queue_free()
	quit(0)
