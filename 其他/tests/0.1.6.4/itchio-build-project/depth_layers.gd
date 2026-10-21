extends RefCounted
## Native rasters, ground bases and visual masks share one coordinate system.
## A vertical strip keeps the contact depth below its own pixels, instead of the
## deepest step/root anywhere in a wide object. Build once, reuse every frame.
## Occlusion depth has a world-space step; image resolution remains untouched.

const DEPTH_STEP_WORLD: float = 2.0

var band_cache: Dictionary = {}
var pond_cache: Dictionary = {}

func _cache_key(texture: Texture2D, key: String) -> String:
	return "%s:%d:%d:%d" % [key, texture.get_instance_id(), texture.get_width(), texture.get_height()]

func _column_bottom(profile: Dictionary, u: float) -> float:
	var bottom := -INF
	for polygon in profile.get("polygons", []):
		for i in range(polygon.size()):
			var a := Vector2(float(polygon[i][0]), float(polygon[i][1]))
			var raw_b: Array = polygon[(i + 1) % polygon.size()]
			var b := Vector2(float(raw_b[0]), float(raw_b[1]))
			if u < minf(a.x, b.x) or u > maxf(a.x, b.x): continue
			if absf(b.x - a.x) < 0.000001:
				if absf(u - a.x) < 0.000001: bottom = maxf(bottom, maxf(a.y, b.y))
			else:
				bottom = maxf(bottom, a.y + (b.y - a.y) * (u - a.x) / (b.x - a.x))
	return bottom

func bands(texture: Texture2D, profile: Dictionary, key: String, world_size: Vector2 = Vector2.ZERO) -> Array[Dictionary]:
	var identity := _cache_key(texture, key)
	var world_height: float = absf(world_size.y)
	if world_height > 0.000001:
		# The same native source can be painted at several world heights. Only
		# this depth scale changes the cache, never its source image or UVs.
		identity += ":world_h:%.9f" % world_height
	if band_cache.has(identity): return band_cache[identity]
	var width := texture.get_width()
	var height := texture.get_height()
	var result: Array[Dictionary] = []
	if width <= 0 or height <= 0:
		band_cache[identity] = result
		return result
	var fallback := float(profile.get("depth_v", 1.0))
	var depths := PackedFloat32Array()
	var left := PackedInt32Array()
	var right := PackedInt32Array()
	depths.resize(width); left.resize(width); right.resize(width)
	var supported_left := -1
	for x in range(width):
		depths[x] = _column_bottom(profile, (float(x) + 0.5) / width)
		if depths[x] != -INF: supported_left = x
		left[x] = supported_left
	var supported_right := -1
	for x in range(width - 1, -1, -1):
		if depths[x] != -INF: supported_right = x
		right[x] = supported_right
	var overhead_gap := bool(profile.get("overhead_gap", false)) or key == "gate" or key.begins_with("gate:")
	for x in range(width):
		if depths[x] != -INF: continue
		var l := left[x]
		var r := right[x]
		if overhead_gap and l >= 0 and r >= 0:
			# Gate's open center still has a painted stone header above the trail.
			depths[x] = fallback
		elif l >= 0 and (r < 0 or x - l <= r - x): depths[x] = depths[l]
		elif r >= 0: depths[x] = depths[r]
		else: depths[x] = fallback
	# Without a world size, retain the original one-source-pixel depth API.
	# Scene painting passes its world size and merges equal two-unit depths.
	# Every source column and row remains present at its native coordinates.
	var depth_units: float = world_height / DEPTH_STEP_WORLD if world_height > 0.000001 else float(height)
	var start := 0
	var level := int(ceil(float(depths[0]) * depth_units))
	for x in range(1, width + 1):
		var next_level := int(ceil(float(depths[x]) * depth_units)) if x < width else level + 1
		if next_level == level: continue
		result.append({"source": Rect2(start, 0, x - start, height), "depth_v": float(level) / depth_units})
		start = x
		level = next_level
	band_cache[identity] = result
	return result

func _segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	var length_sq := segment.length_squared()
	if length_sq <= 0.000001: return point.distance_to(a)
	return point.distance_to(a + segment * clampf((point - a).dot(segment) / length_sq, 0.0, 1.0))

func _owns_pixel(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point, polygon): return true
	for i in range(polygon.size()):
		if _segment_distance(point, polygon[i], polygon[(i + 1) % polygon.size()]) <= 1.0: return true
	return false

func _texture(image: Image) -> Texture2D:
	# RGB edge repair leaves alpha untouched, including exact partition ownership.
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func pond_layers(texture: Texture2D, rock_profile: Dictionary, key: String) -> Dictionary:
	var identity := _cache_key(texture, key)
	if pond_cache.has(identity): return pond_cache[identity]
	var original: Image = texture.get_image().duplicate()
	original.clear_mipmaps()
	original.convert(Image.FORMAT_RGBA8)
	var size := Vector2(original.get_width(), original.get_height())
	var base: Image = original.duplicate()
	var claimed := PackedByteArray()
	claimed.resize(int(size.x * size.y))
	claimed.fill(0)
	var rocks: Array[Dictionary] = []
	var stone_index := 0
	for raw_polygon in rock_profile.get("visual_polygons", rock_profile.get("polygons", [])):
		if raw_polygon.size() < 3: continue
		var polygon := PackedVector2Array()
		var minimum := size
		var maximum := Vector2.ZERO
		for pair in raw_polygon:
			var point := Vector2(float(pair[0]), float(pair[1])) * size
			polygon.append(point)
			minimum = minimum.min(point)
			maximum = maximum.max(point)
		var x0 := maxi(0, int(floor(minimum.x)) - 2)
		var y0 := maxi(0, int(floor(minimum.y)) - 2)
		var x1 := mini(int(size.x), int(ceil(maximum.x)) + 2)
		var y1 := mini(int(size.y), int(ceil(maximum.y)) + 2)
		if x1 <= x0 or y1 <= y0: continue
		var crop := Image.create(x1 - x0, y1 - y0, false, Image.FORMAT_RGBA8)
		crop.fill(Color(0, 0, 0, 0))
		for y in range(y0, y1):
			for x in range(x0, x1):
				var pixel_index := y * int(size.x) + x
				if claimed[pixel_index] != 0 or not _owns_pixel(Vector2(x + 0.5, y + 0.5), polygon): continue
				claimed[pixel_index] = 1
				var color := original.get_pixel(x, y)
				crop.set_pixel(x - x0, y - y0, color)
				color.a = 0.0
				base.set_pixel(x, y, color)
		var crop_origin := Vector2(x0, y0)
		var crop_size := Vector2(x1 - x0, y1 - y0)
		var local_polygon: Array = []
		var local_bottom := -INF
		var local_top := INF
		# Extract the entire painted stone, then derive its depth from its
		# separately authored grounded base. The paired order is validated.
		var raw_ground: Array = rock_profile.polygons[stone_index]
		for pair in raw_ground:
			var point: Vector2 = Vector2(float(pair[0]), float(pair[1])) * size
			var local_point: Vector2 = (point - crop_origin) / crop_size
			local_polygon.append([local_point.x, local_point.y])
			local_bottom = maxf(local_bottom, local_point.y)
			local_top = minf(local_top, local_point.y)
		rocks.append({"texture": _texture(crop), "rect": Rect2(crop_origin / size, crop_size / size), "profile": {"polygons": [local_polygon], "depth_v": local_bottom, "overhead_split_v": clampf(local_top, 0.0, 1.0)}, "source_polygon": raw_polygon.duplicate(true)})
		stone_index += 1
	var result := {"base": _texture(base), "rocks": rocks}
	pond_cache[identity] = result
	return result
