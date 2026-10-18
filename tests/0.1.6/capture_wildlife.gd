extends SceneTree
const OUT := "res://../../tests/0.1.6/"
var game: Variant
var poses: Array = []

func _initialize() -> void: call_deferred("run")

func save_scene(name: String, description: String) -> void:
	game.reset_capture()
	game._draw()
	game.save_capture(name, 1100, 720)
	poses.append({"name":name,"description":description,"phase":game.phase,"player":[game.player.x,game.player.y],"animals":game.wildlife.entries().map(func(a):return {"species":a.species,"p":[a.p.x,a.p.y],"moving":a.moving,"frame":a.frame})})

func stage(species: String, position: Vector2, facing: Vector2, walk: float = 0.0, state: String = "wander") -> Dictionary:
	var old_size: int = game.wildlife.animals.size()
	assert(game.wildlife._spawn_one(game, species))
	var animal: Dictionary = game.wildlife.animals[old_size]
	animal.p = position
	animal.home = position
	animal.goal = position + facing * 100.0
	animal.facing = facing
	animal.age = 10.0
	animal.walk = walk
	animal.moving = state == "wander"
	animal.state = state
	animal.timer = 0.35 if species == "wolf" else 0.60
	animal.locked_aim = game.player
	assert(game.wildlife._ground_clear(game, animal, position), "Preview animal ground is genuinely clear: " + species)
	return animal

func run() -> void:
	game = load(OUT + "snapshot_game.gd").new()
	game.resource_seed = 161
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	assert(game.animal_atlases.size() == 5)
	game.message_time = 0
	game.show_collision = false
	game.day_time = 55
	game.elapsed = 1
	game.bag.add("wood_sword", 1)
	game.auto_equip(int(game.bag.slots[game.bag.first("wood_sword")].uid))
	# Actual seeded populations, without editing their ecological spawn positions.
	for animal in game.wildlife.animals: animal.age = 10.0
	game.player = Vector2(1700,880)
	game.camera = Vector2(1100,430)
	save_scene("wildlife-day-natural", "Actual seeded wildlife population; camera on the eastern trail")
	# A clear labeled demonstration of all three daytime species using the real
	# renderer/assets/colliders. Arrangement is staged, not a claimed encounter.
	game.wildlife.animals.clear()
	stage("rabbit", Vector2(1570,790), Vector2.RIGHT, 20)
	stage("deer", Vector2(1810,740), Vector2.LEFT, 20)
	stage("fox", Vector2(1720,810), Vector2.LEFT, 30)
	save_scene("wildlife-day-demo", "Staged daytime composition: rabbit, deer, fox; actual game Canvas")
	# Same real clearing at night. The near wolf is inside its real attack range;
	# its warning pose is shown while the larger bear approaches from the side.
	game.phase = "night"
	game.night_elapsed = 30
	game.phase_time = 30
	game.player = Vector2(1700,850)
	game.facing = Vector2.LEFT
	game.camera = Vector2(1100,430)
	game.wildlife.animals.clear()
	stage("wolf", Vector2(1657,850), Vector2.RIGHT, 0, "windup")
	stage("bear", Vector2(1840,790), Vector2.LEFT, 25)
	assert(game.walkable(game.player), "The staged close encounter must not overlap player feet")
	game.action = {"target":{"kind":"swing", "pos":Vector2(1657,850)}, "uid":int(game.selected_item().uid), "id":"wood_sword", "elapsed":0.45, "duration":0.8, "hit":false}
	game.message = "A ! warning means a bite or swipe is coming. Move aside, or strike first."
	game.message_time = 5
	save_scene("wildlife-night-demo", "Staged nighttime combat composition: telegraphing wolf and approaching bear")
	game.action.clear()
	game.message_time = 0
	# Fixed art registration over the actual meadow; four frames are independent
	# painted leg keys, not rotated limbs or repeated still-image translation.
	for species in ["rabbit","deer","fox","wolf","bear"]:
		game.phase = "day"
		game.day_time = 55
		game.wildlife.animals.clear()
		game.player = Vector2(1750,920)
		var animal := stage(species, Vector2(1700,790), Vector2.RIGHT)
		for frame in range(4):
			animal.walk = float(game.wildlife.Data.info(species).stride) * frame / 4.0
			save_scene("wildlife-walk-%s-%d" % [species,frame], "Staged registration inspection, actual renderer at world size")
	var file := FileAccess.open(OUT + "wildlife-capture-manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"scenes":poses,"method":"Software replay of actual release Canvas drawing. Natural population is identified separately from staged demonstrations. Not native GPU screenshots."}, "\t"))
	print("WILDLIFE_SCENES_CAPTURED ", poses.size())
	game.queue_free()
	quit()
