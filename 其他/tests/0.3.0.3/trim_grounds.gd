extends SceneTree
# Copies the ground textures into OUT, cutting away any dark frame the image
# generator left along an edge (an edge strip much darker than the interior).
# Only whole rows/columns are removed; no pixel is resampled or repainted.
# SRC=<folder> [SRC2=<folder>] OUT=<folder>
const NAMES := ["ground-valley-grass", "ground-riverbank", "ground-river-water", "ground-river-ford", "ground-ruins-flagstone", "ground-ruins-dry-grass", "ground-path"]

func lum(img: Image, r: Rect2i) -> float:
	var t := 0.0; var n := 0
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
			t += img.get_pixel(x, y).get_luminance(); n += 1
	return t / maxf(1, n)

func _initialize() -> void:
	var out: String = OS.get_environment("OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var report := {}
	for name in NAMES:
		var path := ""
		for src in [OS.get_environment("SRC"), OS.get_environment("SRC2")]:
			if src != "" and FileAccess.file_exists(src.path_join(name + ".png")): path = src.path_join(name + ".png"); break
		if path == "": push_error("missing " + name); quit(1); return
		var img := Image.load_from_file(path); img.convert(Image.FORMAT_RGB8)
		var w := img.get_width(); var h := img.get_height()
		var mid := lum(img, Rect2i(w / 4, h / 4, w / 2, h / 2))
		var cut := {"left": 0, "right": 0, "top": 0, "bottom": 0}
		for side in cut.keys():
			var k := 0
			while k < 80:
				var strip: Rect2i
				match side:
					"left": strip = Rect2i(k, 0, 2, h)
					"right": strip = Rect2i(w - 2 - k, 0, 2, h)
					"top": strip = Rect2i(0, k, w, 2)
					"bottom": strip = Rect2i(0, h - 2 - k, w, 2)
				if lum(img, strip) > mid * 0.8: break
				k += 2
			cut[side] = k + 4 if k > 0 else 0 # a little extra past the dark band
		var rect := Rect2i(cut.left, cut.top, w - cut.left - cut.right, h - cut.top - cut.bottom)
		img.get_region(rect).save_png(out.path_join(name + ".png"))
		report[name] = {"source": path.get_file(), "from": path.get_base_dir().get_file(), "size_in": [w, h], "cut": cut, "size_out": [rect.size.x, rect.size.y]}
		print(name, " ", report[name])
	var f := FileAccess.open(out.path_join("ground-trim.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"resampled": false, "grounds": report}, "  "))
	quit()
