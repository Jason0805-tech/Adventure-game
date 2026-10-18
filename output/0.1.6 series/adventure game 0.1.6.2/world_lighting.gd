extends RefCounted
# Lighting changes paint exposure only. All source art stays at native resolution.
# A coloured Canvas mesh interpolates a continuous field without a GPU-only shader.
const Geometry = preload("res://world_geometry.gd")
const Gait = preload("res://animal_gait.gd")
const METRE := 32.0
const TORCH_RADIUS := 5.0 * METRE
const TORCH_INNER := 1.9 * METRE
const CAMP := Vector2(455, 725)
const CAMP_INNER := 112.0
const CAMP_RADIUS := 205.0
const MESH_STEP := 18.0
const FOG := Color(0.008, 0.014, 0.031)
var _screen := Vector2.ZERO
var _vertices := PackedVector3Array()
var _indices := PackedInt32Array()

func _value(world: Variant, property: String, fallback: Variant) -> Variant:
	var result: Variant = world.get(property)
	return fallback if result == null else result

func _blend_keys(t: float, keys: Array) -> Vector2:
	for i in range(1, keys.size()):
		if t <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var u := smoothstep(float(a[0]), float(b[0]), t)
			return Vector2(float(a[1]), float(a[2])).lerp(Vector2(float(b[1]), float(b[2])), u)
	var last: Array = keys.back()
	return Vector2(float(last[1]), float(last[2]))

func atmosphere(world: Variant) -> Dictionary:
	var phase: String = str(_value(world, "phase", "day"))
	var t := 0.0
	var sky := Color("a8aaa0")
	var title := "DAWN"
	var values := Vector2(0.36, 0.13)
	if phase == "day":
		t = clampf(float(_value(world, "day_time", 0.0)) / maxf(0.1, float(_value(world, "day_duration", 180.0))), 0, 1)
		values = _blend_keys(t, [[0.0, 0.36, 0.13], [0.16, 0.055, 0.045], [0.45, 0.0, 0.0], [0.68, 0.055, 0.035], [1.0, 0.52, 0.16]])
		if t < 0.18:
			title = "DAWN"
			sky = Color("c8a181").lerp(Color("a4b6b0"), smoothstep(0, 0.18, t))
		elif t < 0.65:
			title = "MIDDAY"
			sky = Color("a4b6b0")
		else:
			title = "EVENING"
			sky = Color("a4b6b0").lerp(Color("bb795f"), smoothstep(0.65, 1.0, t))
	elif phase == "dusk":
		t = clampf(float(_value(world, "phase_time", 0.0)) / maxf(0.1, float(_value(world, "dusk_duration", 6.0))), 0, 1)
		values = Vector2(lerpf(0.52, 0.95, smoothstep(0, 1, t)), lerpf(0.16, 0.0, smoothstep(0, 1, t)))
		title = "DUSK"
		sky = Color("bb795f").lerp(Color("28324b"), t)
	elif phase == "night":
		t = clampf(float(_value(world, "night_elapsed", 0.0)) / maxf(0.1, float(_value(world, "night_duration", 90.0))), 0, 1)
		values = _blend_keys(t, [[0.0, 0.95, 0.0], [0.2, 0.98, 0.0], [0.65, 0.98, 0.0], [0.82, 0.92, 0.015], [1.0, 0.36, 0.13]])
		title = "BEFORE DAWN" if t > 0.82 else ("MIDNIGHT" if t >= 0.2 else "NIGHTFALL")
		sky = Color("202b43").lerp(Color("c8a181"), smoothstep(0.82, 1.0, t))
	else:
		# The dawn result panel and next day's first frame share the same exposure.
		values = Vector2(0.36, 0.13)
		sky = Color("c8a181")
	return {"darkness": values.x, "warmth": values.y, "sky": sky, "title": title, "fraction": t}

func _radial(distance: float, inner: float, outer: float) -> float:
	return 1.0 - smoothstep(inner, outer, distance)

func _field_exposure(p: Vector2, dark: float, player: Vector2, torch: bool) -> float:
	var base := 1.0 - dark
	var camp := _radial(p.distance_to(CAMP), CAMP_INNER, CAMP_RADIUS) * 0.96
	var exposure := maxf(base, camp)
	var distance := p.distance_to(player)
	if torch:
		exposure = maxf(exposure, _radial(distance, TORCH_INNER, TORCH_RADIUS) * 0.98)
	# Only one's boots remain barely legible without a torch; this is not a free lantern.
	exposure = maxf(exposure, _radial(distance, 5.0, 22.0) * 0.13)
	return clampf(exposure, 0.0, 1.0)

func _torch_active(world: Variant) -> bool:
	return bool(_value(world, "torch_lit", false)) and float(_value(world, "torch_fuel", 0.0)) > 0

func sample(world: Variant, p: Vector2) -> float:
	return _field_exposure(p, float(atmosphere(world).darkness), _value(world, "player", Vector2.ZERO), _torch_active(world))

func _prepare_grid(screen: Vector2) -> void:
	if screen == _screen and not _vertices.is_empty(): return
	_screen = screen
	_vertices.clear()
	_indices.clear()
	var cols := int(ceil(screen.x / MESH_STEP)) + 1
	var rows := int(ceil(screen.y / MESH_STEP)) + 1
	for y in range(rows):
		for x in range(cols):
			_vertices.append(Vector3(minf(x * MESH_STEP, screen.x), minf(y * MESH_STEP, screen.y), 0))
	for y in range(rows - 1):
		for x in range(cols - 1):
			var a := y * cols + x
			_indices.append_array(PackedInt32Array([a, a + 1, a + cols, a + 1, a + cols + 1, a + cols]))

func darkness_mesh(world: Variant, screen: Vector2) -> ArrayMesh:
	_prepare_grid(screen)
	var dark: float = float(atmosphere(world).darkness)
	var colors := PackedColorArray()
	var camera: Vector2 = _value(world, "camera", Vector2.ZERO)
	var player: Vector2 = _value(world, "player", Vector2.ZERO)
	var torch := _torch_active(world)
	for vertex in _vertices:
		var color := FOG
		color.a = 1.0 - _field_exposure(Vector2(vertex.x, vertex.y) + camera, dark, player, torch)
		colors.append(color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	# New mesh identity also makes deterministic Canvas captures retain each time of day.
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _rect(world: Variant, rect: Rect2, color: Color) -> void:
	if world.has_method("record_draw_rect"): world.record_draw_rect(rect, color)
	else: world.draw_rect(rect, color, true, -1, false)

func _circle(world: Variant, center: Vector2, radius: float, color: Color) -> void:
	if world.has_method("record_draw_circle"): world.record_draw_circle(center, radius, color)
	else: world.draw_circle(center, radius, color, true, -1, true)

func _line_of_sight(world: Variant, start: Vector2, finish: Vector2) -> bool:
	for body in _value(world, "solid_bodies", []):
		# Water is opaque to walking, not to sight.
		if str(body.get("kind", "")) == "water": continue
		if world.has_method("body_active") and not world.body_active(body): continue
		if Geometry.segment_intersects_polygon(start, finish, body.polygon): return false
	return true

func _eye_positions(world: Variant, animal: Dictionary) -> Array:
	if not world.has_method("animal_pose"): return []
	var pose: Dictionary = world.animal_pose(animal)
	if pose.is_empty(): return []
	var metadata: Dictionary = _value(world, "animal_metadata", {}).get(str(animal.species), {})
	var direction: int = int(pose.direction)
	var frame: int = int(pose.frame)
	if metadata.has("gait"):
		var anchored: Array = []
		for offset in Gait.eye_offsets(animal, metadata, pose): anchored.append(animal.p + offset)
		return anchored
	var raw: Array = []
	if metadata.has("poses"):
		var native_pose: Dictionary = metadata.poses[direction][frame]
		raw = native_pose.get("eyes", [])
	if raw.is_empty(): return []
	var result: Array = []
	for pair in raw:
		var eye := Vector2(float(pair[0]), float(pair[1]))
		result.append(animal.p + (eye - pose.anchor) * float(pose.scale))
	return result

func eye_entries(world: Variant) -> Array:
	var result: Array = []
	var dark: float = float(atmosphere(world).darkness)
	if dark < 0.6: return result
	var wildlife: Variant = _value(world, "wildlife", null)
	if wildlife == null: return result
	var player: Vector2 = _value(world, "player", Vector2.ZERO)
	var elapsed: float = float(_value(world, "elapsed", 0.0))
	for animal in wildlife.entries():
		var species := str(animal.species)
		if species not in ["wolf", "bear"]: continue
		var distance: float = animal.p.distance_to(player)
		if distance > 300.0 or distance < 1.0: continue
		var exposure := sample(world, animal.p)
		if exposure >= 0.28 or not _line_of_sight(world, player, animal.p): continue
		var uid := int(animal.get("uid", 0))
		var blink_period := 4.2 + (uid % 5) * 0.43
		if fposmod(elapsed + uid * 0.731, blink_period) > blink_period - 0.12: continue
		var strength := (1.0 - smoothstep(0.05, 0.28, exposure)) * smoothstep(0.6, 0.94, dark)
		strength *= (1.0 - smoothstep(235.0, 300.0, distance)) * float(animal.get("alpha", 1.0))
		var color := Color("e76248") if species == "wolf" else Color("a0d47b")
		for eye in _eye_positions(world, animal):
			result.append({"p": eye, "color": color, "alpha": strength, "species": species, "uid": uid})
	return result

func draw(world: Variant) -> void:
	var screen: Vector2 = world.get_viewport_rect().size
	var sky := atmosphere(world)
	if float(sky.warmth) > 0:
		_rect(world, Rect2(Vector2.ZERO, screen), Color(0.97, 0.55, 0.26, float(sky.warmth)))
	if float(sky.darkness) > 0.0001:
		var mesh := darkness_mesh(world, screen)
		if world.has_method("record_draw_mesh"): world.record_draw_mesh(mesh)
		else: world.draw_mesh(mesh, null, Transform2D.IDENTITY, Color.WHITE)
	var camera: Vector2 = _value(world, "camera", Vector2.ZERO)
	for eye in eye_entries(world):
		var p: Vector2 = eye.p - camera
		var color: Color = eye.color
		_circle(world, p, 2.0, Color(color, 0.10 * float(eye.alpha)))
		_circle(world, p, 1.15, Color(color, 0.8 * float(eye.alpha)))
		_circle(world, p + Vector2(-0.22, -0.22), 0.42, Color(1.0, 0.88, 0.61, float(eye.alpha)))
