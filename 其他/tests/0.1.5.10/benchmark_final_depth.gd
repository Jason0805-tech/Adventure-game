extends SceneTree
const OUT := "res://../../tests/0.1.5.10/"
const ITERATIONS := 100

func stats(values: Array[float]) -> Dictionary:
	var ordered: Array[float] = values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in ordered: total += value
	return {"iterations":ordered.size(),"mean_ms":total/ordered.size()/1000.0,"median_ms":ordered[ordered.size()/2]/1000.0,"p95_ms":ordered[int(ceil(ordered.size()*.95))-1]/1000.0,"minimum_ms":ordered[0]/1000.0,"maximum_ms":ordered[-1]/1000.0}

func measure(game: Variant, visible: bool) -> Dictionary:
	for i in range(5): game.paint_entries(visible)
	var bands_before: int = game.depth_layers.band_cache.size()
	var textures_before: int = game.paint_density.build_count
	var values: Array[float] = []
	var entries: Array[Dictionary] = []
	for i in range(ITERATIONS):
		var start := Time.get_ticks_usec()
		entries = game.paint_entries(visible)
		values.append(float(Time.get_ticks_usec()-start))
	var kinds: Dictionary = {}
	for entry in entries: kinds[entry.kind] = int(kinds.get(entry.kind,0))+1
	var result := stats(values)
	result.merge({"entry_count":entries.size(),"entry_kinds":kinds,"band_cache_before":bands_before,"band_cache_after":game.depth_layers.band_cache.size(),"texture_builds_before":textures_before,"texture_builds_after":game.paint_density.build_count})
	return result

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game: Variant = load("res://main.gd").new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	var fixtures := [{"name":"camp","camera":Vector2(0,250),"player":Vector2(360,760)},{"name":"forest","camera":Vector2(1050,650),"player":Vector2(1550,1100)},{"name":"pond","camera":Vector2(650,200),"player":Vector2(1000,625)}]
	var results: Array = []
	for fixture in fixtures:
		game.camera=fixture.camera; game.player=fixture.player
		var result := {"scene":fixture.name,"camera":[fixture.camera.x,fixture.camera.y],"player":[fixture.player.x,fixture.player.y],"visible_entries":measure(game,true),"full_world_entries":measure(game,false)}
		results.append(result)
		print("FINAL_NATIVE_DEPTH_CPU_BENCH ",fixture.name," visible=",result.visible_entries.entry_count," mean_ms=",result.visible_entries.mean_ms," p95_ms=",result.visible_entries.p95_ms," full=",result.full_world_entries.entry_count," mean_ms=",result.full_world_entries.mean_ms," band_cache=",result.full_world_entries.band_cache_after)
	var cache_bands := 0
	var cache_max := 0
	for bands in game.depth_layers.band_cache.values():
		cache_bands += bands.size()
		cache_max = maxi(cache_max,bands.size())
	var report := {"version":"0.1.5.10","iterations_per_case":ITERATIONS,"godot":Engine.get_version_info(),"viewport":[game.get_viewport_rect().size.x,game.get_viewport_rect().size.y],"scope":"Cached CPU paint_entries construction and sort in native-source-texture runtime. No Canvas command recorder, GPU rendering, physical display, frame time or FPS measurement. Single local headless run; timing varies with concurrent jobs.","scenes":results,"band_cache_entries":game.depth_layers.band_cache.size(),"cached_band_total":cache_bands,"max_bands_per_cached_object":cache_max,"native_texture_cache_entries":game.paint_density.cache_size()}
	var file := FileAccess.open(OUT+"final-depth-cpu-benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	game.queue_free();quit()
