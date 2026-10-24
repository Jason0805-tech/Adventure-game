extends Node2D
## v0.3.0 ground for the expanded world. The original painted forest meadow is
## drawn unchanged in its own rectangle; the valley and ruins are painted from
## tiling ground textures blended by low-resolution material masks, with a
## noise-warped edge so borders look brushed rather than ruled. Source rasters
## are never reduced: textures tile at their native pixel density.
##
## Real art goes in assets/region/ (alpha-3 art: 素材整理/区域_0.3.0_重画). Until a texture
## exists, a placeholder cut from existing painted art is used instead.

const Regions = preload("res://regions.gd")
const MASK_CELL := 16.0
const ART := {
	"valley_grass": "res://assets/region/ground-valley-grass.png",
	"bank": "res://assets/region/ground-riverbank.png",
	"water": "res://assets/region/ground-river-water.png",
	"ford": "res://assets/region/ground-river-ford.png",
	"flagstone": "res://assets/region/ground-ruins-flagstone.png",
	"dry_grass": "res://assets/region/ground-ruins-dry-grass.png",
	"path": "res://assets/region/ground-path.png",
}
# World units covered by the WIDTH of one repeat of each texture; the height
# follows the texture's own aspect ratio (alpha-3: no more square stretching,
# so the painted dabs keep their shape). Chosen so the brush marks read at about
# the same size as the forest meadow's.
const TILE := {"valley_grass": 780.0, "bank": 400.0, "water": 560.0, "ford": 480.0, "flagstone": 640.0, "dry_grass": 760.0, "path": 860.0}

var world_size := Vector2.ZERO
var textures: Dictionary = {}
var placeholder: Dictionary = {} # material -> true when real art is missing
var average: Dictionary = {} # material -> Color, for the world map
var mask_a: ImageTexture
var mask_b: ImageTexture
var map_texture: ImageTexture
var material_ref: ShaderMaterial
var tile_array: Texture2DArray
var tile_size := Vector2i.ONE
const LAYERS := ["valley_grass", "bank", "water", "ford", "flagstone", "dry_grass", "path"]

const SHADER := """
shader_type canvas_item;
// Five samplers only: the web renderer has few texture units for custom
// shaders, so the seven tiling ground textures live in one texture array.
uniform sampler2D meadow : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_a : filter_linear, repeat_disable;
uniform sampler2D mask_b : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear, repeat_enable;
uniform sampler2DArray tiles : filter_linear_mipmap, repeat_enable;
uniform vec2 world_size;
uniform vec4 meadow_rect;
uniform vec4 size_a; // valley, bank, water, ford
uniform vec3 size_b; // flag, dry, path
uniform float aspect = 1.0; // texture height / width
uniform vec3 tint0 = vec3(1.0);
uniform vec3 tint1 = vec3(1.0);
uniform vec3 tint2 = vec3(1.0);
uniform vec3 tint3 = vec3(1.0);
uniform vec3 tint4 = vec3(1.0);
uniform vec3 tint5 = vec3(1.0);
uniform vec3 tint6 = vec3(1.0);
varying vec2 world_pos;

void vertex() { world_pos = VERTEX; }

// alpha-3: the ground textures are made seamless offline (wrap-around), so
// they repeat plainly; the old mirrored fold showed as kaleidoscope patterns.
// Gradients come from the continuous coordinate so mipmaps stay correct
// across the wrap.
vec3 tiled(float layer, vec2 p, float size) {
	vec2 uv = p / vec2(size, size * aspect);
	return textureGrad(tiles, vec3(fract(uv), layer), dFdx(uv), dFdy(uv)).rgb;
}

void fragment() {
	vec2 p = world_pos;
	vec2 n = texture(noise_tex, p / 900.0).rg - 0.5;
	vec2 n2 = texture(noise_tex, p / 230.0 + vec2(0.37, 0.71)).rg - 0.5;
	vec2 warped = p + n * 70.0 + n2 * 22.0;
	vec2 muv = warped / world_size;
	vec4 a = texture(mask_a, muv);
	vec4 b = texture(mask_b, muv);
	// Sharpen the blurred weights into painted, slightly irregular borders.
	float grain = (texture(noise_tex, p / 60.0).r - 0.5) * 0.22;
	a = clamp((a - 0.5 + grain) * 2.6 + 0.5, 0.0, 1.0) * step(0.001, a);
	b = clamp((b - 0.5 + grain) * 2.6 + 0.5, 0.0, 1.0) * step(0.001, b);
	float total = a.r + a.g + a.b + a.a + b.r + b.g + b.b + b.a;
	if (total < 0.0001) { a.r = 1.0; total = 1.0; }
	vec3 colour = vec3(0.0);
	if (a.r > 0.0) {
		vec2 muv2 = (p - meadow_rect.xy) / meadow_rect.zw;
		colour += texture(meadow, clamp(muv2, vec2(0.001), vec2(0.999))).rgb * a.r;
	}
	vec2 flow = vec2(p.y, p.x);
	if (a.g > 0.0) colour += tiled(0.0, p, size_a.x) * tint0 * a.g;
	if (a.b > 0.0) colour += tiled(1.0, p, size_a.y) * tint1 * a.b;
	if (a.a > 0.0) colour += tiled(2.0, flow + vec2(TIME * 14.0, 0.0), size_a.z) * tint2 * a.a;
	if (b.r > 0.0) colour += tiled(3.0, flow + vec2(TIME * 18.0, 0.0), size_a.w) * tint3 * b.r;
	if (b.g > 0.0) colour += tiled(4.0, p, size_b.x) * tint4 * b.g;
	if (b.b > 0.0) colour += tiled(5.0, p, size_b.y) * tint5 * b.b;
	if (b.a > 0.0) colour += tiled(6.0, p, size_b.z) * tint6 * b.a;
	COLOR = vec4(colour / total, 1.0);
}
"""


func setup(meadow: Texture2D, size: Vector2) -> void:
	world_size = size
	show_behind_parent = true
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(false)
	_load_textures(meadow)
	_build_masks(meadow)
	material_ref = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material_ref.shader = shader
	material_ref.set_shader_parameter("meadow", meadow)
	material_ref.set_shader_parameter("mask_a", mask_a)
	material_ref.set_shader_parameter("mask_b", mask_b)
	material_ref.set_shader_parameter("noise_tex", _noise())
	material_ref.set_shader_parameter("world_size", size)
	material_ref.set_shader_parameter("meadow_rect", Vector4(Regions.FOREST.position.x, Regions.FOREST.position.y, Regions.FOREST.size.x, Regions.FOREST.size.y))
	material_ref.set_shader_parameter("size_a", Vector4(TILE.valley_grass, TILE.bank, TILE.water, TILE.ford))
	material_ref.set_shader_parameter("size_b", Vector3(TILE.flagstone, TILE.dry_grass, TILE.path))
	material_ref.set_shader_parameter("tiles", tile_array)
	material_ref.set_shader_parameter("aspect", float(tile_size.y) / tile_size.x)
	for i in range(LAYERS.size()): material_ref.set_shader_parameter("tint%d" % i, _tint(LAYERS[i]))
	material = material_ref
	queue_redraw()
	render_map_texture()

# alpha-4: the world map is a small render of the real ground (the forest meadow
# and the painted region textures through this same shader), so all three
# regions look alike on the map instead of the valley and ruins being flat
# colour. Until it is ready, and in headless runs where nothing is rendered, the
# flat colour map built with the masks stays.
const MAP_UNITS_PER_PIXEL := 3.0
func render_map_texture() -> void:
	if DisplayServer.get_name() == "headless": return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ceili(world_size.x / MAP_UNITS_PER_PIXEL), ceili(world_size.y / MAP_UNITS_PER_PIXEL))
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var canvas := ColorRect.new()
	canvas.size = world_size
	canvas.scale = Vector2.ONE / MAP_UNITS_PER_PIXEL
	canvas.material = material_ref
	viewport.add_child(canvas)
	add_child(viewport)
	for attempt in range(3):
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		if image != null and not image.is_empty() and image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.5:
			image.convert(Image.FORMAT_RGBA8)
			map_texture = ImageTexture.create_from_image(image)
			break
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.queue_free()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, world_size), Color.WHITE)

# --- Textures ------------------------------------------------------------------
func _tint(key: String) -> Vector3:
	if not placeholder.get(key, false): return Vector3.ONE
	# Placeholders are recoloured crops of the forest paint.
	return {"valley_grass": Vector3(0.86, 1.02, 0.98), "dry_grass": Vector3(1.18, 1.03, 0.66),
		"bank": Vector3(1.0, 1.0, 1.0), "water": Vector3(1.0, 1.0, 1.0), "ford": Vector3(1.0, 1.0, 1.0),
		"flagstone": Vector3(1.0, 1.0, 1.0), "path": Vector3(1.0, 1.0, 1.0)}.get(key, Vector3.ONE)

func _load_textures(meadow: Texture2D) -> void:
	textures.clear(); placeholder.clear(); average.clear()
	var meadow_image: Image = meadow.get_image()
	var images: Array[Image] = []
	for key in LAYERS:
		var image: Image = null
		if FileAccess.file_exists(ART[key]): image = Image.load_from_file(ART[key])
		if image == null or image.is_empty():
			image = _placeholder(key, meadow_image)
			placeholder[key] = true
		image.convert(Image.FORMAT_RGBA8)
		if image.has_mipmaps(): image.clear_mipmaps()
		var probe: Image = image.duplicate()
		probe.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		var tint: Vector3 = _tint(key)
		var c: Color = probe.get_pixel(0, 0)
		average[key] = Color(c.r * tint.x, c.g * tint.y, c.b * tint.z)
		images.append(image)
	# All layers of a texture array share one size: the largest width and the
	# largest height, so no texture is ever reduced (a layer a few pixels smaller,
	# e.g. after its dark frame was trimmed, is scaled up to match).
	tile_size = Vector2i.ZERO
	for image in images: tile_size = Vector2i(maxi(tile_size.x, image.get_width()), maxi(tile_size.y, image.get_height()))
	for i in range(images.size()):
		var image: Image = images[i]
		if image.get_size() != tile_size: image.resize(tile_size.x, tile_size.y, Image.INTERPOLATE_LANCZOS)
		image.generate_mipmaps()
		textures[LAYERS[i]] = ImageTexture.create_from_image(image)
	tile_array = Texture2DArray.new()
	tile_array.create_from_images(images)
	var m: Image = meadow_image.duplicate()
	if m.has_mipmaps(): m.clear_mipmaps()
	m.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	average["meadow"] = m.get_pixel(0, 0)

func _placeholder(key: String, meadow: Image) -> Image:
	var scale_x: float = meadow.get_width() / Regions.FOREST.size.x
	match key:
		"valley_grass", "dry_grass":
			# Pure grass area of the painted meadow (north-west corner).
			return meadow.get_region(Rect2i(0, 0, int(900 * scale_x), int(560 * scale_x)))
		"path":
			# The middle of the painted east-west road is a thin strip; stack it
			# (shifted and flipped band by band) into a square so the texture
			# array never stretches it.
			var strip: Image = meadow.get_region(Rect2i(int(60 * scale_x), int(738 * scale_x), int(900 * scale_x), int(38 * scale_x)))
			strip.convert(Image.FORMAT_RGBA8)
			var side: int = strip.get_width()
			var square := Image.create(side, side, false, Image.FORMAT_RGBA8)
			var band: int = strip.get_height()
			var r := RandomNumberGenerator.new(); r.seed = 7171
			var y := 0
			while y < side:
				var piece: Image = strip.duplicate()
				if (y / band) % 2 == 1: piece.flip_y()
				if r.randf() < 0.5: piece.flip_x()
				var shift: int = r.randi_range(0, side - 1)
				square.blit_rect(piece, Rect2i(shift, 0, side - shift, band), Vector2i(0, y))
				square.blit_rect(piece, Rect2i(0, 0, shift, band), Vector2i(side - shift, y))
				y += band
			return square
	return _dabs(key)

func _dabs(key: String) -> Image:
	# Painted placeholder: wrap-around blocky brush dabs on a base colour.
	var palettes := {
		"bank": [Color("b9ab8c"), Color("a3967a"), Color("8f8c86"), Color("c8bea4"), Color("7c8a86"), Color("d2c7aa")],
		"water": [Color("3f7f84"), Color("357177"), Color("4b8d8f"), Color("2f6670"), Color("6aa7a4"), Color("9cc9be")],
		"ford": [Color("6fb2ab"), Color("82bfb4"), Color("9b9a86"), Color("5ea39f"), Color("b7d8c8"), Color("8a9e90")],
		"flagstone": [Color("8d9493"), Color("7f8786"), Color("9fa49c"), Color("6f7a72"), Color("8e9a6e"), Color("a7a99b")],
	}
	var colours: Array = palettes.get(key, palettes.bank)
	var size := 512
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(colours[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var count := 900 if key != "flagstone" else 260
	for i in range(count):
		var w := rng.randi_range(10, 34) if key != "flagstone" else rng.randi_range(46, 96)
		var h := rng.randi_range(6, 16) if key != "flagstone" else rng.randi_range(34, 70)
		if key in ["water", "ford"]: w = rng.randi_range(30, 90); h = rng.randi_range(4, 9)
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		var c: Color = colours[rng.randi_range(1, colours.size() - 1)]
		for ox in [0, -size]:
			for oy in [0, -size]:
				var r := Rect2i(x + ox, y + oy, w, h).intersection(Rect2i(0, 0, size, size))
				if r.size.x > 0 and r.size.y > 0:
					image.fill_rect(r, c)
					if key == "flagstone": image.fill_rect(Rect2i(r.position, Vector2i(r.size.x, 3)), Color("6b6f5c"))
	return image

# --- Masks -----------------------------------------------------------------------
func _build_masks(meadow: Texture2D) -> void:
	var cols := ceili(world_size.x / MASK_CELL)
	var rows := ceili(world_size.y / MASK_CELL)
	var a := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var b := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var map := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var meadow_small: Image = meadow.get_image().duplicate()
	meadow_small.resize(ceili(Regions.FOREST.size.x / MASK_CELL), ceili(Regions.FOREST.size.y / MASK_CELL), Image.INTERPOLATE_LANCZOS)
	var colours: Array = []
	for key in Regions.MATERIALS: colours.append(average.get(key, Color.GRAY))
	for y in range(rows):
		for x in range(cols):
			var p := Vector2((x + 0.5) * MASK_CELL, (y + 0.5) * MASK_CELL)
			var w: PackedFloat32Array = Regions.material_weights(p)
			a.set_pixel(x, y, Color(w[0], w[1], w[2], w[3]))
			b.set_pixel(x, y, Color(w[4], w[5], w[6], w[7]))
			var c := Color(0, 0, 0)
			if w[0] > 0.0 and x < meadow_small.get_width() and y < meadow_small.get_height(): c = meadow_small.get_pixel(x, y) * w[0]
			for i in range(1, w.size()): c += colours[i] * w[i]
			c.a = 1.0
			map.set_pixel(x, y, c)
	_blur(a, 2); _blur(b, 2)
	mask_a = ImageTexture.create_from_image(a)
	mask_b = ImageTexture.create_from_image(b)
	map_texture = ImageTexture.create_from_image(map)

func _blur(image: Image, passes: int) -> void:
	# Cheap blur: shrink and grow back, keeping borders between materials soft.
	var size := image.get_size()
	for i in range(passes):
		image.resize(maxi(1, size.x / 2), maxi(1, size.y / 2), Image.INTERPOLATE_BILINEAR)
		image.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)

func _noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 3017
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var image: Image = noise.get_seamless_image(256, 256, false, false, 0.1, false)
	var image2: Image = noise.get_seamless_image(256, 256, false, false, 0.1, false)
	image.convert(Image.FORMAT_RGBA8)
	# Second channel from a shifted copy so x and y warp independently.
	for y in range(256):
		for x in range(256):
			var c := image.get_pixel(x, y)
			image.set_pixel(x, y, Color(c.r, image2.get_pixel((x + 97) % 256, (y + 41) % 256).r, 0.0, 1.0))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
