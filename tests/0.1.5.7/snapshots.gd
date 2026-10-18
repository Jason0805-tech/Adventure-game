extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game: Variant = load("res://../../tests/0.1.5.7/snapshot_game.gd").new()
	game.resource_seed = 157
	root.add_child(game)
	game.set_process(false)
	game.message_time = 0
	game.day_time = 35
	game.camera = Vector2(0, 250)
	game.player = Vector2(540, 740)
	game.reset_capture(); game._draw(); game.save_capture("day-overview")
	for state in ["behind-logs", "in-front-of-logs"]:
		game.player = Vector2(512, 624 if state == "behind-logs" else 674)
		game.reset_capture(); game._draw(); game.save_capture(state)
	game.player = Vector2(510, 681)
	game.show_collision = true
	game.reset_capture(); game._draw(); game.save_capture("camp-contours")
	game.show_collision = false
	game.player = Vector2(620, 724)
	game.reset_capture(); game._draw(); game.save_capture("workbench-front")
	game.player = Vector2(620, 666)
	game.reset_capture(); game._draw(); game.save_capture("workbench-back")

	var tree: Vector2 = game.trees[0]
	var distance: float = INF
	for candidate in game.trees:
		var score: float = candidate.distance_to(Vector2(1100, 1040))
		if score < distance:
			distance = score
			tree = candidate
	game.player = tree + Vector2(0, 45)
	game.camera = (tree - Vector2(550, 390)).clamp(Vector2.ZERO, game.WORLD - Vector2(1100, 720))
	game.bag.add("stone_axe", 1)
	game.auto_equip(int(game.bag.slots[game.bag.first("stone_axe")].uid))
	game.facing = Vector2.UP
	game.tree_states[tree].shake = 0.3
	for sample in range(4):
		game.elapsed = 0.04 * sample
		game.action = {"target": {"kind": "tree", "pos": tree}, "id": "stone_axe", "uid": int(game.selected_item().uid), "elapsed": 0.35, "duration": 0.8, "hit": false}
		game.reset_capture(); game._draw(); game.save_capture("tree-hit-%02d" % sample)
	game.action.clear()
	game.tree_states[tree].felled = true
	game.rebuild_obstacles()
	game.show_collision = true
	game.reset_capture(); game._draw(); game.save_capture("felled-stump-contour")
	game.show_collision = false

	game.camera = Vector2(610, 260)
	game.player = Vector2(1000, 625)
	game.show_collision = true
	game.reset_capture(); game._draw(); game.save_capture("lake-contours")
	game.show_collision = false
	game.camera = Vector2(100, 480)
	game.player = Vector2(650, 980)
	game.reset_capture(); game._draw(); game.save_capture("forest-detail")

	# Check the actual paint call during repeated hits. Only its rotation changes.
	var identity: Dictionary = {}
	game.tree_states[tree].felled = false
	for sample in range(120):
		game.reset_capture()
		game.varied_tree(tree, false, sin(sample * 0.21) * 0.0135)
		var paint: Dictionary = game.commands[0]
		var current: Dictionary = {"texture": paint.texture.path, "rect": paint.rect, "color": paint.color, "root": paint.transform.slice(0, 2), "scale": paint.transform.slice(3, 5)}
		if sample == 0: identity = current
		assert(current == identity, "Tree paint identity changed during sway")
	print("TREE_HIT_PAINT_IDENTITY_PASSED 120 samples")
	print("SCENE_CAPTURES_COMPLETE 13 scenarios; software Canvas replay")
	quit(0)
