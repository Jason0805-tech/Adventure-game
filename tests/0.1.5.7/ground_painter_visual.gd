extends SceneTree

func _init() -> void:
	call_deferred("capture_ground")

func capture_ground() -> void:
	root.size = Vector2i(1100, 750)
	var ground_script = load("res://ground_painter.gd")
	var ground = ground_script.new()
	root.add_child(ground)
	var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
	ground.setup(texture, Vector2(2200, 1500))
	ground.scale = Vector2(0.5, 0.5)
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var target := ProjectSettings.globalize_path("res://../../tests/0.1.5.7/ground-detail-preview.png")
	var result := capture.save_png(target)
	assert(result == OK)
	print("GROUND_VISUAL_SAVED ", target)
	quit(0)
