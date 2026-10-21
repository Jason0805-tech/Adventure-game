extends SceneTree
## Previous release painted at final release's exact camera and player poses.
const OUT := "res://../../tests/0.1.5.11/"
var game: Variant
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var final: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + "back-front-visibility-final.json"))
	game = load(OUT + "baseline_visual_snapshot_game.gd").new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	game.npc_home = Vector2(50,1450)
	game.npc_position = Vector2(90,1450)
	game.message_time = 0
	game.show_collision = false
	game.day_time = 30
	game.elapsed = 0
	var captures: Array = []
	for pose in final.captures:
		game.player = Vector2(pose.player[0],pose.player[1])
		game.facing = Vector2(pose.facing[0],pose.facing[1])
		game.camera = game.player - Vector2(220,230)
		game.reset_capture()
		game._draw()
		var world: Array = []
		for command in game.commands:
			var transform: Array = command.transform
			if absf(float(transform[0])) < 0.0001 and absf(float(transform[1])) < 0.0001: break
			world.append(command)
		game.commands = world
		var name: String = "visibility-fixed-baseline-" + str(pose.name)
		game.save_capture(name,440,340)
		captures.append({"name":pose.name,"file":name,"player":pose.player,"walkable":game.walkable(game.player)})
	var file := FileAccess.open(OUT + "fixed-baseline-scenes.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":"0.1.5.10","method":"0.1.5.10 actual Canvas commands drawn at exact final 0.1.5.11 camera/player poses. Some positions are blocked in old physics and are intentionally shown for render comparison. Software replay, not native GPU screenshot.","captures":captures},"\t"))
	print("FIXED_BASELINE_CAPTURED ",captures.size())
	game.queue_free()
	quit()
