extends SceneTree

func _init() -> void:
	call_deferred("check_ground")

func check_ground() -> void:
	var ground_script = load("res://ground_painter.gd")
	var ground = ground_script.new()
	root.add_child(ground)
	var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
	ground.setup(texture, Vector2(2200, 1500))
	assert(ground.stroke_count > 50000 and ground.stroke_count < 65000)
	assert(ground.vertex_count == ground.stroke_count * 6)
	assert(ground.detail_mesh.get_surface_count() == 1)
	assert(ground.show_behind_parent and ground.z_index == -10)
	assert(not ground.is_processing())
	var arrays = ground.detail_mesh.surface_get_arrays(0)
	var vertices = arrays[Mesh.ARRAY_VERTEX]
	var colors = arrays[Mesh.ARRAY_COLOR]
	for vertex in vertices:
		assert(vertex.x >= 0 and vertex.y >= 0 and vertex.x <= 2200 and vertex.y <= 1500)
	for color in colors:
		assert(color.a > 0.0 and color.a <= 0.31)
	var first_build := int(ground.build_time_usec)
	ground.setup(texture, Vector2(2200, 1500))
	var repeated = ground.detail_mesh.surface_get_arrays(0)
	assert(vertices == repeated[Mesh.ARRAY_VERTEX])
	assert(colors == repeated[Mesh.ARRAY_COLOR])
	ground.position = Vector2(-400, -300)
	assert(vertices == ground.detail_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	print("GROUND_PASS strokes=", ground.stroke_count, " vertices=", ground.vertex_count, " mesh_surfaces=1 seed_stable=true camera_stable=true build_ms=", float(first_build) / 1000.0)
	ground.setup(null, Vector2(2200, 1500))
	assert(ground.detail_mesh == null and ground.stroke_count == 0)
	ground.queue_free()
	quit(0)
