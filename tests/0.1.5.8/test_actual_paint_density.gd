extends SceneTree

const PaintDensity = preload("res://paint_density.gd")
var checks: int = 0
var failures: int = 0
var records: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL actual paint density: " + label)

func _initialize() -> void:
	call_deferred("_run")

func audit_texture(game: Variant, texture: Texture2D, world_size: Vector2, label: String, require_reduction: bool) -> void:
	var expected: Vector2i = PaintDensity.raster_size(world_size)
	var cache_key: String = "%d:%d:%d" % [texture.get_instance_id(), expected.x, expected.y]
	check(game.paint_density._cache.has(cache_key), label + " is actually prepared by the game before test probes")
	var display: Texture2D = game.paint_density.prepare_rect(texture, world_size)
	var size := Vector2i(display.get_width(), display.get_height())
	var source_texels: int = texture.get_width() * texture.get_height()
	var display_texels: int = size.x * size.y
	var fraction: float = float(display_texels) / maxf(1.0, float(source_texels))
	check(size == expected, label + " uses the same two-world-unit paint sampling as meadow")
	check(display.get_image().has_mipmaps(), label + " uses mipmaps for stable scaled brush detail")
	check(game.paint_density.prepare_rect(texture, world_size) == display, label + " shares the actual cached display texture")
	if require_reduction: check(fraction < 0.055, label + " visibly finer source sampling is reduced by at least 94.5 percent")
	records.append({"label": label, "source_size": [texture.get_width(), texture.get_height()], "world_size": [world_size.x, world_size.y], "display_size": [size.x, size.y], "source_texels": source_texels, "display_texels": display_texels, "retained_texel_fraction": fraction})

func _run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 158
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	# Give CanvasItem its initial render notification when this rendering backend
	# supports it. Cache evidence is recorded independently from later probes.
	await process_frame
	await process_frame
	var initially_cached: int = game.paint_density.cache_size()
	check(game.ground_layer.ground_texture.get_width() == 1100 and game.ground_layer.ground_texture.get_height() == 750, "ground actually uses prepared 1100 x 750 paint texture")
	check(game.ground_layer.detail_mesh == null and game.ground_layer.stroke_count == 0, "old fine speckle overlay is absent from actual ground layer")
	check(game.texture_filter in [CanvasItem.TEXTURE_FILTER_LINEAR, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS], "game uses smooth scaled paint sampling")
	check(game.ground_layer.texture_filter == game.texture_filter, "ground uses the same smooth filter")
	var seen: Dictionary = {}
	for body in game.solid_bodies:
		if body.kind in ["water", "bank_rock"]: continue
		var spec: Dictionary = game.model_spec(str(body.kind), body.p, int(body.index))
		if spec.is_empty(): continue
		var rect: Rect2 = game.sprite_rect(spec.texture, spec.foot, float(spec.height))
		var key: String = str(spec.profile) + ":" + str(rect.size)
		if seen.has(key): continue
		seen[key] = true
		audit_texture(game, spec.texture, rect.size, key, true)
	for index in range(game.pools.size()):
		# The large pond legitimately needs more texels than tiny resources.
		# Its physical texel density must still exactly equal the meadow's.
		audit_texture(game, game.pond_art[index], game.pools[index].size, "pond:%d" % index, false)
	audit_texture(game, game.meadow, game.WORLD, "meadow", false)
	var output_path: String = ProjectSettings.globalize_path("res://").path_join("../../tests/0.1.5.8/actual-paint-density-results.json").simplify_path()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	check(file != null, "sampling evidence output is writable")
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "initial_prepared_display_cache_entries": initially_cached, "native_object_draw_notifications_measured": false, "sampling": records}, "\t"))
	print("ACTUAL_PAINT_DENSITY_RESULTS checks=", checks, " failures=", failures, " textures=", records.size(), " initial_render_cache_entries=", initially_cached)
	game.queue_free()
	quit(0 if failures == 0 else 1)
