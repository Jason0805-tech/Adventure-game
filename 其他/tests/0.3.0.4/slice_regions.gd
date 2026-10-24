extends SceneTree
# Splits the user's v0.3.0 region sheets (alpha-3 repaint) into separate
# sprites WITHOUT resampling: every output pixel is an unchanged source pixel.
# Objects are separated by alpha connectivity; small detached paint (pebbles,
# grass tufts, fallen chips) joins the object it sits beside. Reading order:
# rows top to bottom, then left to right. "single" sheets keep every piece as
# one sprite (the gate's two pillars), only trimming the empty border. The icon
# sheet (3 + 2 layout) is re-packed into the 5 x 1 row main.gd expects, again
# by copying pixels.  SRC=<folder with sheets> OUT=<folder>
const SHEETS := [
	{"file": "ruins-props.png", "rows": 2, "names": ["ruin-column", "ruin-fallen-column", "ruin-wall", "ruin-statue", "ruin-rubble", "ruin-rubble-mined"]},
	{"file": "valley-props.png", "rows": 2, "names": ["valley-willow", "valley-reeds", "valley-reeds-cut", "valley-boulder", "valley-driftwood", "valley-ferry-post"]},
	{"file": "valley-bridge.png", "rows": 1, "names": ["valley-bridge-deck", "valley-dock"]},
	{"file": "ruin-well.png", "rows": 1, "single": true, "names": ["ruin-well"]},
	{"file": "ruin-gate.png", "rows": 1, "single": true, "names": ["ruin-gate"]},
	{"file": "region-item-icons-sheet.png", "rows": 2, "icons": true, "cells": [[0.1667, 0.25], [0.5, 0.25], [0.8333, 0.25], [0.3333, 0.75], [0.6667, 0.75]], "names": ["icon-reeds", "icon-trout", "icon-ancient-stone", "icon-bronze-scrap", "icon-rune-charm"]},
]
const SOLID := 100 # alpha above this is paint
const BIG := 6000 # solid pixels that make an object rather than a fleck

func _initialize() -> void:
	var src: String = OS.get_environment("SRC"); var out: String = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var report := {}
	var icon_pieces: Array = []
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
		var single: bool = sheet.get("single", false)
		if single and big.size() > 0:
			var all_box: Rect2i = big[0].box
			for c in big: all_box = all_box.merge(c.box)
			big = [{"id": big[0].id, "n": 0, "box": all_box, "members": big.map(func(c): return c.id)}]
		if sheet.has("cells"):
			# Icons made of several pieces (bronze scrap): every big piece joins
			# the nearest expected icon position of the 3 + 2 layout.
			var groups: Array = []
			for cc in sheet.cells: groups.append({"id": -1, "n": 0, "box": Rect2i(), "members": []})
			for c in big:
				var centre := Vector2(c.box.get_center()) / Vector2(w, h)
				var best := 0
				for i in range(sheet.cells.size()):
					if centre.distance_to(Vector2(sheet.cells[i][0], sheet.cells[i][1])) < centre.distance_to(Vector2(sheet.cells[best][0], sheet.cells[best][1])): best = i
				var g: Dictionary = groups[best]
				g.box = c.box if g.members.is_empty() else g.box.merge(c.box)
				if g.id < 0: g.id = c.id
				g.members.append(c.id)
			big = groups.filter(func(g): return not g.members.is_empty())
		if big.size() != names.size():
			push_error("%s: expected %d objects, found %d %s" % [sheet.file, names.size(), big.size(), str(big.map(func(c): return [c.box, c.n]))]); quit(1); return
		var rows: int = sheet.rows
		if not sheet.has("cells"): big.sort_custom(func(a, b):
			var ra: int = mini(rows - 1, int(a.box.get_center().y * rows / h))
			var rb: int = mini(rows - 1, int(b.box.get_center().y * rows / h))
			return ra < rb if ra != rb else a.box.position.x < b.box.position.x)
		var owner := PackedInt32Array(); owner.resize(comps.size()); owner.fill(-1)
		for i in range(big.size()):
			for m in big[i].get("members", [big[i].id]): owner[m] = i
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
			if sheet.get("icons", false): icon_pieces.append(piece)
			else: piece.save_png(out.path_join(names[i] + ".png"))
			report[names[i]] = {"sheet": sheet.file, "source_rect": [box.position.x, box.position.y, box.size.x, box.size.y]}
			print(names[i], " ", box)
	if icon_pieces.size() > 0:
		# 5 equal cells in one row, each icon centred; pixels copied unchanged.
		var cell := Vector2i.ZERO
		for p in icon_pieces: cell = Vector2i(maxi(cell.x, p.get_width()), maxi(cell.y, p.get_height()))
		cell += Vector2i(60, 60)
		var row := Image.create(cell.x * icon_pieces.size(), cell.y, false, Image.FORMAT_RGBA8)
		for i in range(icon_pieces.size()):
			var p: Image = icon_pieces[i]
			row.blit_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(i * cell.x + (cell.x - p.get_width()) / 2, (cell.y - p.get_height()) / 2))
		row.save_png(out.path_join("region-item-icons.png"))
		report["region-item-icons"] = {"packed_from": "region-item-icons-sheet.png", "cell": [cell.x, cell.y], "count": icon_pieces.size()}
	var f := FileAccess.open(out.path_join("region-slices.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"resampled": false, "objects": report}, "  "))
	quit()
