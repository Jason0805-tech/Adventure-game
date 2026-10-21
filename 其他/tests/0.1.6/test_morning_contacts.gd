extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(text)
func run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 161
	root.add_child(game)
	game.set_process(false)
	game.wildlife.animals.clear()
	var rock_indices: Array[int] = []
	for index in range(game.items.size()):
		if game.items[index].kind == "rock": rock_indices.append(index)
	assert(rock_indices.size() >= 3)
	for index in rock_indices.slice(0,3): game.collect_item(index)
	game.player = game.items[rock_indices[0]].pos
	check(game.static_walkable(game.player), "Player starts on legal collected ground")
	assert(game.wildlife._spawn_one(game, "rabbit"))
	var animal: Dictionary = game.wildlife.animals[0]
	animal.p = game.items[rock_indices[1]].pos
	animal.home = animal.p
	animal.age = 10.0
	animal.facing = Vector2.DOWN
	check(game.wildlife._ground_clear(game,animal,animal.p), "Animal starts on legal collected ground")
	game.phase = "result"
	game.survived = 1
	game.next_day()
	check(game.static_walkable(game.player), "Dawn cannot grow a solid rock under the player's boots")
	check(game.wildlife._ground_clear(game,animal,animal.p), "Dawn cannot grow a solid rock under animal paws")
	check(not game.items[rock_indices[2]].taken, "Unoccupied collected rocks still regrow normally")
	var before: int = game.bag.count("rock")
	game.collect_item(rock_indices[2])
	check(game.bag.count("rock") == before + 1, "Regrown resources restore their collectible quantity")
	print("MORNING_CONTACT_CHECKS ", checks, " failures=", failures)
	game.queue_free()
	quit(0 if failures == 0 else 1)
