extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> bool:
	if condition:
		print("PASS  ", message)
		return true
	push_error("FAIL  " + message)
	quit(1)
	return false

func route_clear(game: Variant, origin: Vector2, direction: Vector2) -> bool:
	for step in range(37):
		if not game.walkable(origin + direction.normalized() * 108.0 * float(step) / 36.0):
			return false
	return true

func _run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var origin := Vector2.ZERO
	for y in range(250, 1250, 80):
		for x in range(250, 1900, 80):
			var candidate := Vector2(x, y)
			if route_clear(game, candidate, Vector2.RIGHT) and route_clear(game, candidate, Vector2.ONE):
				origin = candidate
				break
		if origin != Vector2.ZERO: break
	if not check(origin != Vector2.ZERO, "clear movement test route exists"): return
	game.player = origin
	game.move_player(Vector2.RIGHT, 1.0)
	if not check(is_equal_approx(game.player.distance_to(origin), 108.0), "straight movement covers 108 units in one second"): return
	game.player = origin
	game.move_player(Vector2.ONE, 1.0)
	if not check(is_equal_approx(game.player.distance_to(origin), 108.0), "diagonal movement has the same speed"): return
	game.update_walk(game.player.distance_to(origin))
	if not check(game.moving and game.avatar_frame() > 0, "walking animation advances with the faster movement"): return
	game.day_time = 0.0
	if not check(game.clock_text() == "03:00", "day starts with a three-minute countdown"): return
	game.advance_day(90.0)
	if not check(game.phase == "day" and is_equal_approx(game.day_fraction(), 0.5) and game.clock_text() == "01:30", "90 seconds is midday and still daylight"): return
	game.paused = true
	game.advance_day(30.0)
	if not check(is_equal_approx(game.day_time, 90.0), "pause freezes the longer day"): return
	game.paused = false
	game.inventory = true
	game.crafting = true
	game.dialog = "test dialog"
	game.advance_day(89.5)
	if not check(game.phase == "day" and game.clock_text() == "00:01", "daylight continues until the 180-second boundary"): return
	game.advance_day(0.5)
	if not check(game.phase == "dusk" and not game.inventory and not game.crafting and game.dialog.is_empty(), "night begins automatically at 180 seconds and closes panels"): return
	game.phase = "result"
	game.next_day()
	if not check(game.phase == "day" and game.night == 2 and game.clock_text() == "03:00", "next morning resets to a full three-minute day"): return
	print("ALL_PACING_SMOKES_PASSED")
	quit(0)
