extends SceneTree

const DEST = "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.7/profile-sprites"

func _initialize() -> void:
	var game = load("res://main.gd").new()
	game.load_art()
	DirAccess.make_dir_recursive_absolute(DEST)
	var entries: Dictionary = {}
	for i in range(6): entries["tree_%d" % i] = game.art[i] if i < 3 else game.variant_art[i - 3]
	for i in range(4): entries["shrub_%d" % i] = game.art[3] if i == 0 else game.variant_art[i + 2]
	entries.cabin = game.prop_art[0]
	for i in range(6): entries["prop_%d" % i] = game.prop_art[i]
	entries.bench = game.utility_props[0]
	for i in range(2): entries["stump_%d" % i] = game.utility_props[i + 1]
	for i in range(3): entries["ore_%d" % i] = game.utility_props[i + 3]
	for row in range(3):
		for i in range(3):
			var kind = ["branch", "rock", "rope"][row]
			entries["resource_%s_%d" % [kind, i]] = game.harvest_art[row * 3 + i]
			entries["resource_%s_spent_%d" % [kind, i]] = game.harvest_art[row * 3 + i + 9]
	entries.gate = game.art[5]
	for i in range(3): entries["pond_%d" % i] = game.pond_art[i]
	var meta: Dictionary = {}
	for key in entries:
		var texture: Texture2D = entries[key]
		texture.get_image().save_png(DEST + "/" + key + ".png")
		var anchor: Vector2 = game.foot_anchors.get(texture, Vector2(texture.get_width() * 0.5, texture.get_height()))
		meta[key] = {"width": texture.get_width(), "height": texture.get_height(), "anchor": [anchor.x, anchor.y]}
	var out = FileAccess.open(DEST + "/sprite-metadata.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(meta, "\t"))
	game.free()
	print("PROFILE_SPRITES_EXPORTED ", entries.size())
	quit()
