extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func save_scene(game: Variant, name: String) -> void:
	game.reset_capture(); game._draw(); game.save_capture(name)

func capture() -> void:
	var game: Variant = load("res://../../tests/0.1.5.8/snapshot_game.gd").new()
	game.resource_seed = 157
	root.add_child(game)
	game.set_process(false)
	game.message_time = 0
	game.day_time = 35
	game.camera = Vector2(0, 250)
	game.player = Vector2(360, 760)
	save_scene(game, "day-camp")
	game.show_collision = true
	save_scene(game, "complete-house-solid")
	game.player = Vector2(512, 760)
	game.move_player(Vector2.UP, 2.0)
	assert(game.walkable(game.player))
	save_scene(game, "log-contact")
	game.camera = Vector2(610, 260)
	game.player = Vector2(1000, 625)
	save_scene(game, "all-bank-stones")
	game.camera = Vector2(1100, 0)
	game.player = Vector2(1990, 400)
	save_scene(game, "stone-gate")
	game.show_collision = false
	game.camera = Vector2(210, 470)
	game.player = Vector2(660, 980)
	save_scene(game, "world-paint-density")
	print("SCENE_CAPTURES_COMPLETE 6 software Canvas replays")
	quit(0)
