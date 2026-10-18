extends SceneTree

const Density = preload("res://paint_density.gd")
const BASE = "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech"
const DEST = BASE + "/tests/0.1.5.8/density-renders"
const SOURCES = BASE + "/tests/0.1.5.7/profile-sprites"

func _initialize() -> void:
	var density = Density.new()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCES + "/sprite-metadata.json"))
	var result: Dictionary = {"units_per_texel": Density.UNITS_PER_TEXEL, "objects": {}, "assertions": 0}
	for key in meta:
		var original: Image = Image.load_from_file(SOURCES + "/" + key + ".png")
		var source_data: PackedByteArray = original.get_data()
		var source: Texture2D = ImageTexture.create_from_image(original)
		var world_height: float = 38.0
		if key.begins_with("tree_"): world_height = 168.0
		elif key.begins_with("shrub_"): world_height = 60.0
		elif key.begins_with("ore_"): world_height = 62.0
		elif key.begins_with("stump_"): world_height = 46.0
		elif key == "cabin" or key == "prop_0": world_height = 222.0
		elif key == "bench": world_height = 82.0
		elif key == "gate": world_height = 132.0
		elif key.begins_with("prop_"): world_height = [222.0, 49.0, 49.0, 46.0, 34.0, 46.0][int(key.get_slice("_", 1))]
		elif key.begins_with("resource_rock"): world_height = 30.0
		if "_spent_" in key: world_height *= 0.48
		var world_size: Vector2 = Vector2(float(source.get_width()) / source.get_height() * world_height, world_height)
		if key.begins_with("pond_"):
			world_size = [Vector2(330,230), Vector2(220,150), Vector2(210,135)][int(key.get_slice("_",1))]
		var prepared: Texture2D = density.prepare_rect(source, world_size)
		var target: Vector2i = Density.raster_size(world_size)
		assert(Vector2i(prepared.get_width(), prepared.get_height()) == target)
		assert(prepared == density.prepare_rect(source, world_size))
		assert(original.get_data() == source_data and source.get_image().get_data() == source_data)
		var prepared_image: Image = prepared.get_image()
		var repeat: Image = Density.resample_image(original, target)
		assert(repeat.get_data() == prepared_image.get_data())
		assert(prepared_image.has_mipmaps())
		assert(float(world_size.x) / target.x <= 2.0 and float(world_size.y) / target.y <= 2.0)
		original.save_png(DEST + "/" + key + "-before.png")
		prepared_image.save_png(DEST + "/" + key + "-after.png")
		result.objects[key] = {"source": [source.get_width(), source.get_height()], "display": [target.x,target.y], "world": [world_size.x,world_size.y], "anchor": meta[key].anchor}
		result.assertions += 6
	var meadow: Image = Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png"))
	var base: Texture2D = ImageTexture.create_from_image(meadow)
	var prepared_ground: Texture2D = density.prepare_rect(base, Vector2(2200,1500))
	assert(Vector2i(prepared_ground.get_width(),prepared_ground.get_height()) == Vector2i(1100,750))
	meadow.save_png(DEST + "/meadow-before.png")
	prepared_ground.get_image().save_png(DEST + "/meadow-after.png")
	result.objects.meadow = {"source": [meadow.get_width(),meadow.get_height()], "display": [1100,750], "world": [2200,1500], "anchor": [0,0]}
	var cutout := Image.create(32,32,false,Image.FORMAT_RGBA8)
	cutout.fill(Color(0,0,1,0))
	cutout.fill_rect(Rect2i(8,8,16,16), Color(1,0,0,1))
	var red_edge: Image = Density.resample_image(cutout, Vector2i(7,7))
	for y in range(7):
		for x in range(7):
			var pixel: Color = red_edge.get_pixel(x,y)
			if pixel.a > 0.05: assert(pixel.r > 0.97 and pixel.b < 0.025)
	assert(density.cache_size() == meta.size() + 1 and density.build_count == meta.size() + 1)
	var file := FileAccess.open(DEST + "/density-metadata.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("PAINT_DENSITY_PASS objects=",meta.size()," assertions=",result.assertions + 3," world_units_per_texel=2 ground=1100x750 source_unmodified=true cache_stable=true deterministic=true premultiplied_edges=true")
	quit(0)
