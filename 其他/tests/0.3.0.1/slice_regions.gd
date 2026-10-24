extends SceneTree
# Splits the user's v0.3.0 region sheets into separate sprites WITHOUT
# resampling: every output pixel is an unchanged source pixel. Objects are
# separated by alpha connectivity; small detached paint (pebbles, grass tufts,
# fallen chips) joins the object it sits beside. Reading order: rows top to
# bottom, then left to right.  SRC=<folder with sheets> OUT=<folder>
const SHEETS := [
	{"file": "ruins-props.png", "rows": 2, "names": ["ruin-column", "ruin-fallen-column", "ruin-wall", "ruin-statue", "ruin-rubble", "ruin-rubble-mined"]},
	{"file": "valley-props.png", "rows": 2, "names": ["valley-willow", "valley-reeds", "valley-reeds-cut", "valley-boulder", "valley-driftwood", "valley-ferry-post"]},
	{"file": "valley-bridge.png", "rows": 1, "names": ["valley-bridge-deck", "valley-dock"]},
]
const SOLID := 100 # alpha above this is paint
const BIG := 6000 # solid pixels that make an object rather than a fleck

func _initialize() -> void:
	var src: String = OS.get_environment("SRC"); var out: String = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var report := {}
	for sheet in SHEETS:
		var img := Image.load_from_file(src.path_join(sheet.file)); img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width(); var h := img.get_height()
		var data := img.get_data()
		print(sheet.file, " ", w, "x", h, " corner alpha ", data[3], " ", data[(w * h - 1) * 4 + 3])
		var label := PackedInt32Array(); label.resize(w * h); label.fill(-1)
		var comps: Array = []
		for start in range(w * h):
			if label[start] != -1 or data[start * 4 + 3] <= SOLID: continue
			var id := comps.size(); var stack := PackedInt32Array([start]); label[start] = id
			var x0 := w; var y0 := h; var x1 := 0; var y1 := 0; var n := 0
			while stack.size() > 0:
				var j: int = stack[stack.size() - 1]; stack.resize(stack.size() - 1)
				var x := j % w; var y := j / w; n += 1
				x0 = mini(x0, x); y0 = mini(y0, y); x1 = maxi(x1, x); y1 = maxi(y1, y)
				for k in [j + 1 if x + 1 < w else -1, j - 1 if x > 0 else -1, j + w if y + 1 < h else -1, j - w if y > 0 else -1]:
					if k >= 0 and label[k] == -1 and data[k * 4 + 3] > SOLID: label[k] = id; stack.append(k)
			comps.append({"id": id, "n": n, "box": Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)})
		# Soft edges (alpha 9..SOLID) join whichever paint reaches them first.
		var frontier := PackedInt32Array()
		for j in range(w * h): if label[j] >= 0: frontier.append(j)
		var head := 0
		while head < frontier.size():
			var j: int = frontier[head]; head += 1
			var x := j % w
			for k in [j + 1 if x + 1 < w else -1, j - 1 if x > 0 else -1, j + w if j + w < w * h else -1, j - w]:
				if k >= 0 and label[k] == -1 and data[k * 4 + 3] > 8: label[k] = label[j]; frontier.append(k)
		var big: Array = comps.filter(func(c): return c.n > BIG)
		var names: Array = sheet.names
		if big.size() != names.size():
			push_error("%s: expected %d objects, found %d %s" % [sheet.file, names.size(), big.size(), str(big.map(func(c): return [c.box, c.n]))]); quit(1); return
		var rows: int = sheet.rows
		big.sort_custom(func(a, b):
			var ra: int = mini(rows - 1, int(a.box.get_center().y * rows / h))
			var rb: int = mini(rows - 1, int(b.box.get_center().y * rows / h))
			return ra < rb if ra != rb else a.box.position.x < b.box.position.x)
		var owner := PackedInt32Array(); owner.resize(comps.size()); owner.fill(-1)
		for i in range(big.size()): owner[big[i].id] = i
		for c in comps:
			if owner[c.id] != -1 or c.n < 4: continue
			var best := -1; var dist := INF
			for i in range(big.size()):
				var b: Rect2i = big[i].box
				var gap := Vector2(maxi(0, maxi(b.position.x - c.box.end.x, c.box.position.x - b.end.x)), maxi(0, maxi(b.position.y - c.box.end.y, c.box.position.y - b.end.y))).length()
				if gap <= 40 and gap < dist: dist = gap; best = i
			owner[c.id] = best
		for i in range(big.size()):
			var box := Rect2i(); var first := true
			for c in comps:
				if owner[c.id] == i: box = c.box if first else box.merge(c.box); first = false
			box = box.grow(4).intersection(Rect2i(0, 0, w, h))
			var piece := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
			for y in range(box.size.y):
				for x in range(box.size.x):
					var j := (box.position.y + y) * w + box.position.x + x
					var l := label[j]
					if l >= 0 and owner[l] == i: piece.set_pixel(x, y, img.get_pixel(box.position.x + x, box.position.y + y))
			piece.save_png(out.path_join(names[i] + ".png"))
			report[names[i]] = {"sheet": sheet.file, "source_rect": [box.position.x, box.position.y, box.size.x, box.size.y]}
			print(names[i], " ", box)
	var f := FileAccess.open(out.path_join("region-slices.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"resampled": false, "objects": report}, "  "))
	quit()
