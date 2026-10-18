extends SceneTree
## Fixed-seed software Canvas replays, with unchanged camera and actor poses.
## Run baseline under the 0.1.5.9 project; final under 0.1.5.10.
const OUT := "res://../../tests/0.1.5.10/"
var game: Variant
var manifest: Array = []
var tag := "final"

func _initialize() -> void:
	call_deferred("run")

func save_scene(name: String, camera: Vector2, player: Vector2) -> void:
	game.camera = camera
	game.player = player
	game.reset_capture()
	game._draw()
	var world: Array = []
	for command in game.commands:
		var t: Array = command.transform
		if absf(float(t[0])) < 0.0001 and absf(float(t[1])) < 0.0001: break
		world.append(command)
	game.commands = world
	game.save_capture("quality-" + tag + "-" + name, 640, 480)
	manifest.append({"name":name,"tag":tag,"camera":[camera.x,camera.y],"player":[player.x,player.y],"size":[640,480],"commands":world.size(),"player_walkable":game.walkable(player)})

func run() -> void:
	var baseline := "baseline" in OS.get_cmdline_user_args()
	if baseline: tag = "baseline"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "captures"))
	game = load(OUT + ("baseline_snapshot_game.gd" if baseline else "snapshot_game.gd")).new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	game.day_time = 30
	game.elapsed = 0
	game.message_time = 0
	game.show_collision = false
	game.facing = Vector2.DOWN
	game.npc_home = Vector2(50,1450)
	game.npc_position = Vector2(90,1450)
	# The same world setup and approved avatar design in both runs; final actor
	# images may be rerendered at higher resolution without changing world bounds.
	save_scene("camp", Vector2(80,360), Vector2(360,730))
	save_scene("forest", Vector2(540,880), Vector2(860,1240))
	save_scene("pond", Vector2(780,230), Vector2(1100,630))
	var file := FileAccess.open(OUT + "quality-scenes-" + tag + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"resource_seed":159,"method":"Software replay of actual ordered Canvas commands. Identical player, facing, camera, world seed and time; not native GPU screenshots.","scenes":manifest},"\t"))
	print("QUALITY_SCENES_CAPTURED ", tag, " ", manifest.size())
	game.queue_free()
	quit()
