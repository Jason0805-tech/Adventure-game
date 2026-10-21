extends SceneTree

func _init() -> void:
	call_deferred("capture_ground")

func capture_ground() -> void:
	var canvas = load("res://../../tests/0.1.5.7/capture_canvas.gd").new()
	root.add_child(canvas)
	var ground = load("res://ground_painter.gd").new()
	root.add_child(ground)
	var texture := ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
	ground.setup(texture, Vector2(2200, 1500))
	# A close crop at the game's actual world-pixel scale highlights the brush
	# size. Both captures use the same base texture and camera position.
	var crop_camera := Vector2(280, 380)
	canvas.reset_capture()
	canvas.record_draw_set_transform(-crop_camera)
	canvas.record_draw_texture_rect(texture, Rect2(Vector2.ZERO, Vector2(2200, 1500)), false)
	canvas.save_capture("ground-before", 1100, 720)
	canvas.reset_capture()
	canvas.record_ground_layer(ground, crop_camera)
	canvas.save_capture("ground-after", 1100, 720)
	print("GROUND_CANVAS_CAPTURES_COMPLETE strokes=", ground.stroke_count)
	ground.queue_free()
	canvas.queue_free()
	quit(0)
