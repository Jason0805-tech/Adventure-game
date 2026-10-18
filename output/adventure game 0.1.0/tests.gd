extends SceneTree
var failures := 0
func check(condition: bool, title: String) -> void:
	if condition: print("PASS: " + title)
	else:
		failures += 1
		push_error("FAIL: " + title)
func _initialize() -> void:
	call_deferred("run_tests")
func run_tests() -> void:
	var game = load("res://main.gd").new()
	root.add_child(game)
	game.set_process(false)
	check(game.walkable(game.player), "Spawn is walkable")
	check(not game.walkable(Vector2(1000, 400)), "Lake collision")
	check(not game.walkable(Vector2(300, 550)), "Cabin collision")
	check(not game.walkable(Vector2(-1, 750)), "World boundary")
	var start: Vector2 = game.player
	game.move_player(Vector2(1, 1), 0.1)
	check(absf(game.player.distance_to(start) - 24) < 0.01, "Diagonal speed normalized")
	game.player = game.npc_home
	game.interact()
	check(game.quest and not game.dialog.is_empty(), "NPC quest dialogue")
	game.dialog = ""
	game.craft()
	check(not game.sword and game.branches == 0, "Cannot craft without materials")
	game.branches = 3
	game.rocks = 4
	game.ropes = 3
	game.collect_item(0)
	check(not game.items[0].taken and game.branches == 3, "Capacity rejects excess materials")
	game.craft()
	check(game.sword and game.branches + game.rocks + game.ropes == 0, "Craft consumes exact recipe")
	game.craft()
	check(game.branches == 0, "Repeat craft cannot consume more materials")
	game.player = game.gate
	game.interact()
	check(not game.won, "Exit locked without crystals")
	for i in range(game.items.size()):
		if game.items[i].kind == "crystal":
			game.collect_item(i)
			game.collect_item(i)
	check(game.crystals == 3, "Crystals picked once each")
	game.interact()
	check(game.won, "Exit completes quest")
	# Flood-fill navigable world to catch unreachable materials and quest targets.
	var queue: Array[Vector2i] = [Vector2i(36, 76)]
	var visited := {Vector2i(36, 76): true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + dir
			if not visited.has(next) and game.walkable(Vector2(next) * 10):
				visited[next] = true
				queue.append(next)
	var reachable := true
	var targets: Array[Vector2] = [game.npc_home, game.npc_scout, game.gate]
	for item in game.items: targets.append(item.pos)
	for target in targets:
		var near := false
		for cell in queue:
			if (Vector2(cell) * 10).distance_to(target) < 65:
				near = true
				break
		if not near:
			reachable = false
			print("Unreachable: ", target)
	check(reachable, "All resources, NPCs and exit reachable from spawn")
	print("TEST RESULT: ", failures, " failures")
	game.queue_free()
	quit(failures)
