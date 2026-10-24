extends SceneTree
# Ground-footprint collision profiles for the v0.3.0 region sprites. Physical
# collision is only the ground base (bottom band of the reference silhouette,
# inset at the sides); everything above is paint. States of one model (rubble
# and mined rubble, reeds and cut reeds) share the SAME world footprint, so a
# state change can never trap an actor. Pixels are copied unchanged.
# SLICES=<production folder> ASSETS=<game assets/region folder>
const GROUPS := [
	# alpha-3 repaint: every sprite now sits on a skirt of leafy tufts, so the
	# insets are wider than before to keep the footprint on the object itself.
	{"model": "column", "states": ["ruin-column"], "ref_height": 100.0, "base": 0.16, "inset": 0.22},
	{"model": "fallen_column", "states": ["ruin-fallen-column"], "ref_height": 60.0, "base": 0.45, "inset": 0.10},
	{"model": "wall", "states": ["ruin-wall"], "ref_height": 66.0, "base": 0.40, "inset": 0.08},
	{"model": "statue", "states": ["ruin-statue"], "ref_height": 100.0, "base": 0.20, "inset": 0.16},
	{"model": "rubble", "states": ["ruin-rubble", "ruin-rubble-mined"], "reference": "ruin-rubble", "ref_height": 52.0, "base": 0.42, "inset": 0.12},
	{"model": "willow", "states": ["valley-willow"], "ref_height": 185.0, "base": 0.07, "inset": 0.38},
	{"model": "reeds", "states": ["valley-reeds", "valley-reeds-cut"], "reference": "valley-reeds", "ref_height": 62.0, "base": 0.22, "inset": 0.18},
	{"model": "boulder", "states": ["valley-boulder"], "ref_height": 50.0, "base": 0.45, "inset": 0.10},
	{"model": "driftwood", "states": ["valley-driftwood"], "ref_height": 44.0, "base": 0.45, "inset": 0.06},
	{"model": "ferry_post", "states": ["valley-ferry-post"], "ref_height": 80.0, "base": 0.16, "inset": 0.28},
	{"model": "well", "states": ["ruin-well"], "ref_height": 112.0, "base": 0.34, "inset": 0.10},
	# The gate's two pillars get SEPARATE footprints (split at the image
	# middle) so the road passes between them.
	{"model": "gate", "states": ["ruin-gate"], "ref_height": 150.0, "base": 0.22, "inset": 0.12, "split": true},
]
const DECALS := ["valley-bridge-deck", "valley-dock"]

func anchor(img: Image) -> Vector2:
	# Same rule as main.gd foot_anchor(): lowest solid row, alpha-weighted
	# centre of the bottom 8 percent.
	var sole := img.get_height() - 1
	for y in range(img.get_height() - 1, -1, -1):
		var hit := false
		for x in range(img.get_width()):
			if img.get_pixel(x, y).a > 0.5: hit = true; break
		if hit: sole = y; break
	var total := 0.0; var wx := 0.0
	for y in range(maxi(0, sole - int(img.get_height() * 0.08)), sole + 1):
		for x in range(img.get_width()):
			var a := img.get_pixel(x, y).a
			if a > 0.5: total += a; wx += (x + 0.5) * a
	return Vector2(wx / total if total > 0 else img.get_width() * 0.5, sole + 1)

func _lowest_row(img: Image, half: Vector2i) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in range(half.x, half.y):
			if img.get_pixel(x, y).a > 0.5: return y
	return img.get_height() - 1

func extents(img: Image, y: int, half: Vector2i = Vector2i(0, 1 << 30)) -> Vector2i:
	var l := -1; var r := -1
	for x in range(maxi(0, half.x), mini(img.get_width(), half.y)):
		if img.get_pixel(x, y).a > 0.5:
			if l < 0: l = x
			r = x
	return Vector2i(l, r)

func _initialize() -> void:
	var src: String = OS.get_environment("SLICES"); var out: String = OS.get_environment("ASSETS")
	DirAccess.make_dir_recursive_absolute(out)
	var profiles := {}; var models := {}
	for g in GROUPS:
		var reference: String = g.get("reference", g.states[0])
		var ref := Image.load_from_file(src.path_join(reference + ".png"))
		var ref_anchor := anchor(ref)
		var scale: float = float(g.ref_height) / ref.get_height() # world units per source pixel
		var halves: Array = [Vector2i(0, ref.get_width())]
		if g.get("split", false): halves = [Vector2i(0, ref.get_width() / 2), Vector2i(ref.get_width() / 2, ref.get_width())]
		var shapes: Array = [] # world-unit polygons, one per ground base
		for half in halves:
			var bottom: int = _lowest_row(ref, half) if g.get("split", false) else int(ref_anchor.y - 1)
			var top: int = int(bottom + 1 - g.base * ref.get_height())
			var left: Array[Vector2] = []; var right: Array[Vector2] = []
			var rows := 8
			for k in range(rows + 1):
				var y: int = int(lerpf(top, bottom, float(k) / rows))
				var e := extents(ref, y, half)
				if e.x < 0: continue
				var inset: float = (e.y - e.x) * float(g.inset)
				left.append((Vector2(e.x + inset, y) - ref_anchor) * scale)
				right.append((Vector2(e.y - inset, y) - ref_anchor) * scale)
			right.reverse()
			shapes.append(left + right)
		var states := {}
		for s in g.states:
			var img := Image.load_from_file(src.path_join(s + ".png"))
			img.save_png(out.path_join(s + ".png"))
			var a := anchor(img)
			var size := Vector2(img.get_width(), img.get_height())
			var polys := []
			var max_v := 0.0; var min_v := 1.0
			for world in shapes:
				var poly := []
				for p in world:
					var uv: Vector2 = (a + p / scale) / size
					poly.append([snappedf(uv.x, 0.001), snappedf(uv.y, 0.001)])
					max_v = maxf(max_v, uv.y); min_v = minf(min_v, uv.y)
				polys.append(poly)
			var key: String = "region_" + s.replace("-", "_")
			profiles[key] = {"polygons": polys, "depth_v": snappedf(max_v - 0.015, 0.001), "overhead_split_v": snappedf(min_v, 0.001), "collision_space": "ground_plane",
				"notes": "v0.3.0 %s ground base: bottom %d%% of the %s silhouette, inset %d%% each side, shared world footprint across states. Elevated paint is visual only." % [g.model, int(g.base * 100), reference, int(g.inset * 100)]}
			states[s] = {"profile": key, "height": snappedf(img.get_height() * scale, 0.01)}
			if shapes.size() == 2:
				# World x of the middle of the passage, relative to the foot anchor.
				var inner_left: float = -INF; var inner_right: float = INF
				for p in shapes[0]: inner_left = maxf(inner_left, p.x)
				for p in shapes[1]: inner_right = minf(inner_right, p.x)
				states[s]["gap_x"] = snappedf((inner_left + inner_right) * 0.5, 0.1)
				states[s]["gap_width"] = snappedf(inner_right - inner_left, 0.1)
		models[g.model] = states
	for name in DECALS:
		var img := Image.load_from_file(src.path_join(name + ".png"))
		img.save_png(out.path_join(name + ".png"))
		models[name] = {"size": [img.get_width(), img.get_height()]}
	# The game reads these PNGs directly (Image.load_from_file); "keep" makes
	# Godot export the original file instead of a compressed texture.
	for file in DirAccess.get_files_at(out):
		if file.ends_with(".png"):
			var keep := FileAccess.open(out.path_join(file + ".import"), FileAccess.WRITE)
			keep.store_string("[remap]\nimporter=\"keep\"\n")
	var f := FileAccess.open(out.path_join("region_models.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"models": models, "profiles": profiles}, "  "))
	print(JSON.stringify(models))
	quit()
