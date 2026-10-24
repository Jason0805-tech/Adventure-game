extends SceneTree
# Makes each ground texture tile seamlessly (wrap-around) at its native size.
# Two passes: blend the image with a copy shifted half a width, then the
# result with a copy shifted half a height. The shifted copy is used only
# near the edges (where it is continuous across the wrap); the switch follows
# a wavy noise line ~60 px wide so it reads as brushwork, not a ruled fade.
# Resolution and dimensions are unchanged.  SRC=<folder> OUT=<folder>
const NAMES := ["ground-valley-grass", "ground-riverbank", "ground-river-water", "ground-river-ford", "ground-ruins-flagstone", "ground-ruins-dry-grass", "ground-path"]

func weight(t: float, n: float) -> float:
	return smoothstep(0.26, 0.36, t + n)

func pass_blend(src: PackedByteArray, w: int, h: int, horizontal: bool, noise: FastNoiseLite) -> PackedByteArray:
	var out := PackedByteArray(); out.resize(src.size())
	var half := (w if horizontal else h) / 2
	for y in range(h):
		for x in range(w):
			var c := x if horizontal else y
			var span := w if horizontal else h
			var t := minf(c, span - c) / (span * 0.5)
			var k := weight(t, noise.get_noise_2d(x, y) * 0.12)
			var sx := (x + half) % w if horizontal else x
			var sy := y if horizontal else (y + half) % h
			var i := (y * w + x) * 4; var j := (sy * w + sx) * 4
			for ch in range(3):
				out[i + ch] = int(round(src[i + ch] * k + src[j + ch] * (1.0 - k)))
			out[i + 3] = 255
	return out

func _initialize() -> void:
	var src: String = OS.get_environment("SRC"); var dst: String = OS.get_environment("OUT")
	var noise := FastNoiseLite.new(); noise.seed = 3031; noise.frequency = 0.006; noise.fractal_octaves = 3
	for name in NAMES:
		var img := Image.load_from_file(src.path_join(name + ".png")); img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width(); var h := img.get_height()
		var data := pass_blend(img.get_data(), w, h, true, noise)
		noise.seed += 1
		data = pass_blend(data, w, h, false, noise)
		var outimg := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
		outimg.convert(Image.FORMAT_RGB8)
		outimg.save_png(dst.path_join(name + ".png"))
		print(name, " ", w, "x", h, " seamless")
	quit()
