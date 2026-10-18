extends RefCounted
## Display-only paint sampling. Geometry and anchors always use the source texture.
## All scenery is sampled at the meadow's physical brush scale, then drawn with
## linear filtering. Small objects therefore cannot retain a much finer grain.

const UNITS_PER_TEXEL: float = 2.0
var _cache: Dictionary = {}
var build_count: int = 0

func prepare(texture: Texture2D, world_height: float, units_per_texel: float = UNITS_PER_TEXEL) -> Texture2D:
	if texture == null: return null
	var aspect: float = float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
	return prepare_rect(texture, Vector2(world_height * aspect, world_height), units_per_texel)

func prepare_rect(texture: Texture2D, world_size: Vector2, units_per_texel: float = UNITS_PER_TEXEL) -> Texture2D:
	if texture == null: return null
	var pixels: Vector2i = raster_size(world_size, units_per_texel)
	var key: String = "%d:%d:%d" % [texture.get_instance_id(), pixels.x, pixels.y]
	if _cache.has(key): return _cache[key]
	var source: Image = texture.get_image()
	if source == null or source.is_empty(): return texture
	var display: Image = resample_image(source, pixels)
	var prepared: ImageTexture = ImageTexture.create_from_image(display)
	_cache[key] = prepared
	build_count += 1
	return prepared

static func raster_size(world_size: Vector2, units_per_texel: float = UNITS_PER_TEXEL) -> Vector2i:
	var density: float = maxf(0.25, units_per_texel)
	return Vector2i(maxi(2, ceili(absf(world_size.x) / density)), maxi(2, ceili(absf(world_size.y) / density)))

static func resample_image(source: Image, pixels: Vector2i) -> Image:
	# Resize premultiplied colour so invisible RGB cannot bleed into edge strokes.
	# Convert back to straight alpha because CanvasItem uses normal alpha blending.
	var image: Image = source.duplicate()
	if image.has_mipmaps(): image.clear_mipmaps()
	image.convert(Image.FORMAT_RGBA8)
	image.premultiply_alpha()
	image.resize(pixels.x, pixels.y, Image.INTERPOLATE_LANCZOS)
	var bytes: PackedByteArray = image.get_data()
	for offset in range(0, bytes.size(), 4):
		var alpha: int = bytes[offset + 3]
		if alpha > 0:
			for channel in range(3):
				bytes[offset + channel] = mini(255, roundi(float(bytes[offset + channel]) * 255.0 / float(alpha)))
		else:
			bytes[offset] = 0
			bytes[offset + 1] = 0
			bytes[offset + 2] = 0
	image = Image.create_from_data(pixels.x, pixels.y, false, Image.FORMAT_RGBA8, bytes)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return image

func clear_cache() -> void:
	_cache.clear()
	build_count = 0

func cache_size() -> int:
	return _cache.size()
