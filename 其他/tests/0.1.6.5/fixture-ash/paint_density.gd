extends RefCounted
## Preserve every source pixel. Display size changes only the Canvas draw rect;
## it never changes the resolution, alpha, colour, or brushwork of a texture.
## Mipmaps provide stable minification without replacing the native base image.

var _cache: Dictionary = {}
var build_count: int = 0

# Keep the public arguments for existing scene callers. World dimensions and the
# retired density argument intentionally have no effect on the prepared image.
func prepare(texture: Texture2D, _world_height: float, _retired_density: float = 0.0) -> Texture2D:
	return _native_texture(texture)

func prepare_rect(texture: Texture2D, _world_size: Vector2, _retired_density: float = 0.0) -> Texture2D:
	return _native_texture(texture)

func _native_texture(texture: Texture2D) -> Texture2D:
	if texture == null: return null
	var identity: int = texture.get_instance_id()
	if _cache.has(identity): return _cache[identity]
	var source: Image = texture.get_image()
	if source == null or source.is_empty(): return texture
	var prepared: Texture2D = texture
	if not source.has_mipmaps():
		# Do not convert, repair edges, premultiply, resize, or sharpen the base.
		# Art loading already repairs atlas edges before this display-only cache.
		var image: Image = source.duplicate()
		image.generate_mipmaps()
		prepared = ImageTexture.create_from_image(image)
	_cache[identity] = prepared
	build_count += 1
	return prepared

func is_prepared(texture: Texture2D) -> bool:
	return texture != null and _cache.has(texture.get_instance_id())

func source_dimensions(texture: Texture2D) -> Vector2i:
	if texture == null: return Vector2i.ZERO
	return Vector2i(texture.get_width(), texture.get_height())

func clear_cache() -> void:
	_cache.clear()
	build_count = 0

func cache_size() -> int:
	return _cache.size()
