extends Node2D

# A permanent world-space paint layer. The original meadow still defines its
# roads and colour masses; small, irregular strokes bring its brush scale closer
# to the harvest props. Building one mesh avoids thousands of draw calls/frame.
const DEFAULT_SEED := 15763021
const STROKE_SPACING := 7.4

var ground_texture: Texture2D
var world_size := Vector2.ZERO
var detail_mesh: ArrayMesh
var stroke_count := 0
var vertex_count := 0
var build_time_usec := 0

func setup(texture: Texture2D, size: Vector2, seed_value: int = DEFAULT_SEED) -> void:
	ground_texture = texture
	world_size = size
	show_behind_parent = true
	z_index = -10
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)
	_build_detail_mesh(seed_value)
	queue_redraw()

func _draw() -> void:
	if ground_texture != null:
		draw_texture_rect(ground_texture, Rect2(Vector2.ZERO, world_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, world_size), Color("71927b"))
	if detail_mesh != null:
		draw_mesh(detail_mesh, null)

func _build_detail_mesh(seed_value: int) -> void:
	var started := Time.get_ticks_usec()
	detail_mesh = null
	stroke_count = 0
	vertex_count = 0
	if ground_texture == null or world_size.x <= 0 or world_size.y <= 0:
		build_time_usec = Time.get_ticks_usec() - started
		return
	var source := ground_texture.get_image()
	if source == null or source.is_empty():
		build_time_usec = Time.get_ticks_usec() - started
		return
	if source.is_compressed():
		source.decompress()
	var source_size := Vector2(source.get_width(), source.get_height())
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var columns := ceili(world_size.x / STROKE_SPACING)
	var rows := ceili(world_size.y / STROKE_SPACING)
	vertices.resize(columns * rows * 6)
	colors.resize(columns * rows * 6)
	var cursor := 0
	for row in range(rows):
		for column in range(columns):
			# Jitter plus skipped cells avoids a grid or a repeated stamp pattern.
			if rng.randf() < 0.07:
				continue
			var center := Vector2((column + rng.randf()) * STROKE_SPACING, (row + rng.randf()) * STROKE_SPACING)
			if center.x > world_size.x - 5 or center.y > world_size.y - 5 or center.x < 5 or center.y < 5:
				continue
			var sample_point := center / world_size * source_size
			var paint := source.get_pixel(clampi(int(sample_point.x), 0, source.get_width() - 1), clampi(int(sample_point.y), 0, source.get_height() - 1))
			# Local colours retain road edges. A small warm/cool value variation
			# behaves like paint picked up by a brush, with no high-frequency speckle.
			var value_shift := rng.randf_range(-0.082, 0.075)
			var warmth := rng.randf_range(-0.009, 0.009)
			paint.r = clampf(paint.r + value_shift + warmth, 0, 1)
			paint.g = clampf(paint.g + value_shift, 0, 1)
			paint.b = clampf(paint.b + value_shift - warmth, 0, 1)
			paint.a = rng.randf_range(0.17, 0.31)
			var axis := Vector2.from_angle(rng.randf_range(-1.12, -0.30))
			# Grass and path share the same fine brush scale, but earth has
			# shorter, softer marks so that the paths remain easy to read.
			var path_paint := paint.r > paint.g * 1.04 and paint.r > paint.b * 1.35
			var length := rng.randf_range(2.1, 5.8) * (0.80 if path_paint else 1.0)
			var width := rng.randf_range(0.75, 1.85)
			if path_paint:
				paint.a *= 0.73
			var across := Vector2(-axis.y, axis.x)
			var head := center + axis * length * 0.5
			var tail := center - axis * length * 0.5
			var a := tail - across * width * rng.randf_range(0.35, 0.57)
			var b := head - across * width * rng.randf_range(0.23, 0.55) + axis * rng.randf_range(-0.45, 0.20)
			var c := head + across * width * rng.randf_range(0.28, 0.61)
			var d := tail + across * width * rng.randf_range(0.34, 0.62) + axis * rng.randf_range(-0.18, 0.39)
			var faded := paint
			faded.a *= rng.randf_range(0.45, 0.75)
			vertices[cursor] = a
			vertices[cursor + 1] = b
			vertices[cursor + 2] = c
			vertices[cursor + 3] = a
			vertices[cursor + 4] = c
			vertices[cursor + 5] = d
			colors[cursor] = faded
			colors[cursor + 1] = paint
			colors[cursor + 2] = faded
			colors[cursor + 3] = faded
			colors[cursor + 4] = faded
			colors[cursor + 5] = paint
			cursor += 6
			stroke_count += 1
	vertices.resize(cursor)
	colors.resize(cursor)
	vertex_count = cursor
	if cursor > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_COLOR] = colors
		detail_mesh = ArrayMesh.new()
		detail_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	build_time_usec = Time.get_ticks_usec() - started
