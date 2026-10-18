extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 157
	root.add_child(game)
	game.set_process(false)
	var index: int = -1
	for i in range(game.items.size()):
		if game.items[i].kind == "branch":
			index = i
			break
	assert(index >= 0)
	var point: Vector2 = game.items[index].pos
	var revision: int = game.nav_revision
	var outside: Dictionary = {}
	for y in range(game.nav_grid.region.size.y):
		for x in range(game.nav_grid.region.size.x):
			var id := Vector2i(x, y)
			var world: Vector2 = game.nav_grid.get_point_position(id)
			if absf(world.x - point.x) > 120 or absf(world.y - point.y) > 120:
				outside[id] = game.nav_grid.is_point_solid(id)
	game.collect_item(index)
	assert(game.items[index].taken and game.bag.count("branch") > 0)
	assert(game.nav_revision == revision + 1)
	for name in game.npc_states: assert(game.npc_states[name].replan == 0.0)
	var checked := 0
	for y in range(game.nav_grid.region.size.y):
		for x in range(game.nav_grid.region.size.x):
			var id := Vector2i(x, y)
			var world: Vector2 = game.nav_grid.get_point_position(id)
			if absf(world.x - point.x) < 70 and absf(world.y - point.y) < 70:
				assert(game.nav_grid.is_point_solid(id) == not game.static_walkable(world))
				checked += 1
	for id in outside: assert(game.nav_grid.is_point_solid(id) == outside[id])
	game.items.insert(0, {"pos": Vector2(600, 900), "kind": "log", "taken": true, "dropped": true, "qty": 1})
	game.phase = "result"
	game.next_day()
	for body in game.solid_bodies:
		if body.kind == "resource": assert(body.p == game.items[int(body.index)].pos)
	print("NAVIGATION_REFRESH_PASSED ", checked, " local cells; ", outside.size(), " distant cells unchanged; morning indices match")
	quit(0)
