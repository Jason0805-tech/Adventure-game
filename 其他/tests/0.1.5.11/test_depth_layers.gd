extends SceneTree

var checks := 0
var failures: Array[String] = []
var Layers = preload("res://depth_layers.gd")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures.append(label)

func texture(width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			image.set_pixel(x, y, Color(float(x % 11) / 10.0, float(y % 7) / 6.0, 0.45, float((x * 17 + y * 11) % 256) / 255.0))
	return ImageTexture.create_from_image(image)

func expanded(bands: Array[Dictionary], width: int) -> Array:
	var levels: Array = []
	levels.resize(width)
	for band in bands:
		var source: Rect2 = band.source
		for x in range(int(source.position.x), int(source.end.x)): levels[x] = float(band.depth_v)
	return levels

func verify_partition(layers: Variant, tex: Texture2D, profile: Dictionary, key: String) -> Dictionary:
	var before: PackedByteArray = tex.get_image().get_data()
	var split: Dictionary = layers.pond_layers(tex, profile, key)
	check(tex.get_image().get_data() == before, key + " source is unchanged")
	var original: Image = tex.get_image()
	var base: Image = split.base.get_image()
	var width := original.get_width()
	var height := original.get_height()
	var sum_alpha := PackedInt32Array()
	var owners := PackedInt32Array()
	sum_alpha.resize(width * height); owners.resize(width * height)
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			sum_alpha[index] = int(round(base.get_pixel(x, y).a * 255.0))
			owners[index] = 1 if sum_alpha[index] > 0 else 0
	for rock in split.rocks:
		var rect: Rect2 = rock.rect
		var image: Image = rock.texture.get_image()
		var ox := int(round(rect.position.x * width))
		var oy := int(round(rect.position.y * height))
		check(int(round(rect.size.x * width)) == image.get_width(), key + " crop width")
		check(int(round(rect.size.y * height)) == image.get_height(), key + " crop height")
		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var index := (y + oy) * width + x + ox
				var alpha := int(round(image.get_pixel(x, y).a * 255.0))
				sum_alpha[index] += alpha
				if alpha > 0: owners[index] += 1
		var local: Array[Dictionary] = layers.bands(rock.texture, rock.profile, key + ":rock:" + str(ox) + ":" + str(oy))
		check(not local.is_empty(), key + " cropped rock has local depth bands")
	for y in range(height):
		for x in range(width):
			var index := y * width + x
			check(sum_alpha[index] == int(round(original.get_pixel(x, y).a * 255.0)), key + " alpha conserved at " + str(Vector2i(x, y)))
			check(owners[index] <= 1, key + " exclusive pixel ownership at " + str(Vector2i(x, y)))
	check(layers.pond_layers(tex, profile, key).base == split.base, key + " pond cache reuses texture")
	return {"rocks": split.rocks.size(), "pixels": width * height}

func _initialize() -> void:
	var layers = Layers.new()
	var tex := texture(16, 16)
	var slope := {"polygons": [[[0.0, 0.1], [1.0, 0.1], [1.0, 1.0], [0.0, 0.5]]], "depth_v": 1.0}
	var bands: Array[Dictionary] = layers.bands(tex, slope, "slope")
	var levels := expanded(bands, 16)
	var consumed := 0
	for band in bands:
		check(int(band.source.position.x) == consumed, "bands have no gap or overlap")
		check(int(band.source.size.y) == 16, "bands include full source height")
		consumed += int(band.source.size.x)
	check(consumed == 16, "all columns preserved")
	for x in range(16):
		var expected := 0.5 + 0.5 * (x + 0.5) / 16.0
		check(float(levels[x]) >= expected and float(levels[x]) - expected <= 1.0 / 16.0 + 0.000001, "slope local lower envelope " + str(x))
	var cache_size: int = layers.band_cache.size()
	layers.bands(tex, slope, "slope")
	check(layers.band_cache.size() == cache_size, "band cache stable")
	var narrow := {"polygons": [[[0.25, 0.2], [0.75, 0.2], [0.75, 0.75], [0.25, 0.75]]], "depth_v": 0.95}
	for depth in expanded(layers.bands(tex, narrow, "narrow"), 16): check(absf(float(depth) - 0.75) < 0.00001, "outside columns use nearest real contact")
	var arch := {"polygons": [[[0.1, 0.1], [0.3, 0.1], [0.3, 0.5], [0.1, 0.5]], [[0.7, 0.1], [0.9, 0.1], [0.9, 0.75], [0.7, 0.75]]], "depth_v": 0.9375}
	var arch_levels := expanded(layers.bands(tex, arch, "gate"), 16)
	check(float(arch_levels[7]) == 0.9375, "open gate center keeps header depth")
	check(float(arch_levels[3]) == 0.5, "gate left pillar has own depth")
	check(float(arch_levels[12]) == 0.75, "gate right pillar has own depth")
	var synthetic := {"polygons": [[[0.15, 0.15], [0.6, 0.2], [0.55, 0.7], [0.2, 0.8]], [[0.4, 0.3], [0.85, 0.3], [0.9, 0.8], [0.5, 0.9]]]}
	var synthetic_result := verify_partition(layers, texture(32, 20), synthetic, "synthetic-overlapping")
	check(synthetic_result.rocks == 2, "each synthetic rock retained")
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://collision_profiles.json"))
	var pond_results: Array = []
	for i in range(3):
		var image := Image.load_from_file(ProjectSettings.globalize_path("res://../../tests/0.1.5.8/density-renders/pond_%d-after.png" % i))
		var pond_texture := ImageTexture.create_from_image(image)
		var result := verify_partition(layers, pond_texture, profiles["pond_%d_rocks" % i], "actual-pond-%d" % i)
		check(result.rocks == [7, 5, 5][i], "all actual shore rocks extracted " + str(i))
		pond_results.append(result)
	var report := {"checks": checks, "failures": failures, "ponds": pond_results, "band_cache_entries": layers.band_cache.size(), "note": "Isolated module tests, exact source alpha partition and local contour depths; not a native manual playthrough."}
	var file := FileAccess.open("res://../../tests/0.1.5.11/depth-layers-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("DEPTH_LAYERS_TESTS ", checks, " checks ", failures.size(), " failures")
	for failure in failures.slice(0, 12): push_error(failure)
	quit(0 if failures.is_empty() else 1)
