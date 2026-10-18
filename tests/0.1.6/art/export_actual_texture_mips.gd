extends SceneTree
func _initialize() -> void:
	var game = load("res://main.gd").new()
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json")).species
	var report: Dictionary = {}
	var out: String = "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6/art/mip-qa"
	DirAccess.make_dir_recursive_absolute(out)
	for species in meta:
		var texture: Texture2D = game.load_texture(str(meta[species].path))
		var image: Image = texture.get_image()
		var bytes: PackedByteArray = image.get_data()
		var levels: Array = []
		for level in range(4):
			var width: int = maxi(1, image.get_width() >> level)
			var height: int = maxi(1, image.get_height() >> level)
			var offset: int = image.get_mipmap_offset(level)
			var part: Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, bytes.slice(offset, offset + width * height * 4))
			var path: String = out.path_join("%s-mip%d.png" % [species, level])
			part.save_png(path)
			levels.append({"level": level, "width": width, "height": height, "bytes": width * height * 4})
		report[species] = {"mip_count": image.get_mipmap_count(), "levels": levels}
	FileAccess.open(out.path_join("godot-load-texture-report.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("WILDLIFE_ACTUAL_LOAD_TEXTURE_MIPS ", JSON.stringify(report))
	game.free()
	quit()

