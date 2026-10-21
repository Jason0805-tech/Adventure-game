extends SceneTree

const PaintDensity = preload("res://paint_density.gd")
var checks: int = 0
var failures: int = 0
var records: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL native quality: " + label)

func base_bytes(texture: Texture2D) -> PackedByteArray:
	var image: Image = texture.get_image().duplicate()
	if image.has_mipmaps(): image.clear_mipmaps()
	return image.get_data()

func _initialize() -> void:
	call_deferred("_run")

func audit_texture(sampler: Variant, texture: Texture2D, world_size: Vector2, label: String, expected_prepared: bool) -> void:
	if expected_prepared: check(sampler.is_prepared(texture), label + " was prepared by actual game warm-up")
	var before: PackedByteArray = base_bytes(texture)
	var original_size := Vector2i(texture.get_width(), texture.get_height())
	var display: Texture2D = sampler.prepare_rect(texture, world_size)
	var prepared_size := Vector2i(display.get_width(), display.get_height())
	check(prepared_size == original_size, label + " keeps every native source row and column")
	check(base_bytes(display) == before, label + " preserves every base RGB and alpha byte")
	check(base_bytes(texture) == before, label + " does not mutate source pixels")
	check(display.get_image().has_mipmaps(), label + " supports smooth GPU minification")
	check(sampler.prepare_rect(texture, world_size * 0.25) == display, label + " different smaller world size shares native cached texture")
	check(sampler.prepare_rect(texture, world_size * 3.0, 50.0) == display, label + " retired density cannot reduce image detail")
	check(sampler.prepare(texture, world_size.y * 2.0) == display, label + " height-based API shares native texture")
	var old_size := Vector2i(maxi(2, ceili(absf(world_size.x) / 2.0)), maxi(2, ceili(absf(world_size.y) / 2.0)))
	var previous_count := old_size.x * old_size.y
	var native_count := original_size.x * original_size.y
	records.append({"label": label, "world_size": [world_size.x, world_size.y], "native_size": [original_size.x, original_size.y], "prepared_size": [prepared_size.x, prepared_size.y], "base_pixels_byte_identical": base_bytes(display) == before, "old_0159_prepared_size": [old_size.x, old_size.y], "native_texels": native_count, "previous_prepared_texels": previous_count, "retained_native_texel_fraction": 1.0, "texel_increase_over_0159": float(native_count) / maxf(1.0, float(previous_count))})

func test_independent_rgba() -> void:
	# This deliberately irregular image has partial alpha and hidden RGB. Exact
	# base preservation catches colour loss caused by premultiply/unpremultiply.
	var image := Image.create(31, 19, false, Image.FORMAT_RGBA8)
	for y in range(19):
		for x in range(31):
			image.set_pixel(x, y, Color8((x * 13 + y * 7) % 256, (x * 5 + y * 11) % 256, (x * 17 + y * 3) % 256, (x * 19 + y * 23) % 256))
	var texture := ImageTexture.create_from_image(image)
	var sampler: Variant = PaintDensity.new()
	check(sampler.prepare_rect(null, Vector2.ONE) == null, "null texture remains null")
	audit_texture(sampler, texture, Vector2(1.2, 0.9), "independent fractional-alpha image without existing mipmaps", false)
	check(sampler.cache_size() == 1 and sampler.build_count == 1, "one source creates exactly one cache entry across sizes")
	var identical_source := ImageTexture.create_from_image(image)
	check(sampler.prepare_rect(identical_source, Vector2(1.2, 0.9)) != sampler.prepare_rect(texture, Vector2(1.2, 0.9)), "separate source identities do not collide in cache")
	check(sampler.cache_size() == 2, "two source identities retain separate cache entries")
	sampler.clear_cache()
	check(sampler.cache_size() == 0 and sampler.build_count == 0, "cache can be cleared without changing source pixels")
	check(base_bytes(texture) == image.get_data(), "cache clear leaves independent source unchanged")

func _run() -> void:
	test_independent_rgba()
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 158
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	await process_frame
	await process_frame
	var initial_cache: int = game.paint_density.cache_size()
	var seen: Dictionary = {}
	for body in game.solid_bodies:
		if body.kind in ["water", "bank_rock"]: continue
		var spec: Dictionary = game.model_spec(str(body.kind), body.p, int(body.index))
		if spec.is_empty(): continue
		var rect: Rect2 = game.sprite_rect(spec.texture, spec.foot, float(spec.height))
		var key: String = str(spec.profile) + ":" + str(rect.size)
		if seen.has(key): continue
		seen[key] = true
		audit_texture(game.paint_density, spec.texture, rect.size, key, true)
	for index in range(game.pools.size()):
		audit_texture(game.paint_density, game.pond_art[index], game.pools[index].size, "pond:%d" % index, true)
	var used_blends: Dictionary = {}
	for detail in game.ground_details: used_blends[int(detail.variant)] = true
	for index in range(game.blend_art.size()):
		audit_texture(game.paint_density, game.blend_art[index], Vector2(250, 160), "ground-blend:%d" % index, used_blends.has(index))
	for index in range(game.resource_art.size()):
		audit_texture(game.paint_density, game.resource_art[index], Vector2(30, 26), "dropped-material:%d" % index, false)
	audit_texture(game.paint_density, game.meadow, game.WORLD, "meadow", true)
	check(game.ground_layer.ground_texture.get_size() == game.meadow.get_size(), "actual ground layer receives full native meadow")
	check(base_bytes(game.ground_layer.ground_texture) == base_bytes(game.meadow), "actual ground layer retains every native meadow base pixel")
	check(game.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "game uses smooth mipmapped display filter")
	check(game.ground_layer.texture_filter == game.texture_filter, "ground uses the same smooth display filter")
	var output_path: String = ProjectSettings.globalize_path("res://").path_join("../../tests/0.1.5.11/native-quality-results.json").simplify_path()
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	check(file != null, "quality evidence output is writable")
	if file != null:
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "initial_cache_entries": initial_cache, "tested_preparations": records.size(), "native_resolution_and_base_pixels_preserved": failures == 0, "measurements": records}, "\t"))
	print("NATIVE_QUALITY_RESULTS checks=", checks, " failures=", failures, " preparations=", records.size(), " initial_cache_entries=", initial_cache)
	game.queue_free()
	quit(0 if failures == 0 else 1)
