extends SceneTree
var failures := 0
var checks := 0
const Game = preload("res://main.gd")
func check(value: bool, title: String) -> void:
	checks += 1
	if value: print("PASS ", title)
	else:
		failures += 1
		push_error("FAIL " + title)
func fresh():
	var game = Game.new()
	game.build_world()
	return game
func night_action(game, action: int) -> void:
	game.start_night()
	game.advance_phase(2.1)
	game.choose_action(action)
	game.advance_phase(2.6)
func _initialize() -> void:
	for i in range(5):
		var g = fresh()
		var r: Array = g.RECIPES[i]
		g.branches = r[1]; g.rocks = r[2]; g.ropes = r[3]
		g.craft_recipe(i)
		check(g.power == r[4] and g.weapons == [r[0]] and g.branches + g.rocks + g.ropes == 0, "Recipe " + r[0])
		g.free()
	var g = fresh()
	g.rocks = 1; g.craft_recipe(5)
	check(g.rocks == 1 and g.weapons.is_empty(), "Upgrade requires base sword")
	g.weapons.append("Large stone sword"); g.power = 4
	g.craft_recipe(5)
	check(g.power == 5 and g.rocks == 0 and g.weapons == ["Amazing stone sword"], "Upgrade costs only one rock and replaces base")
	g.craft_recipe(0)
	check(g.power == 5 and g.branches == 0, "Insufficient materials have no side effects")
	g.branches = 5; g.rocks = 1; g.ropes = 2; g.craft_recipe(4)
	check(g.power == 9 and g.weapons.size() == 2, "Weapon power adds up")
	g.free()
	for action in range(3):
		g = fresh(); g.power = 10
		g.start_night()
		check(g.phase == "dusk" and g.fullness == 100, "Night starts without charging an action")
		g.paused = true; g.advance_phase(9)
		check(g.phase == "dusk", "Pause freezes transition")
		g.paused = false; g.advance_phase(2.1)
		g.choose_action(9)
		check(g.phase == "choice" and g.fullness == 100, "Invalid action cannot charge fullness")
		g.choose_action(action)
		check(g.power == 10 + [2, 1, 1][action] and g.fullness == [50, 65, 100][action], "Action power and fullness " + str(action))
		check(g.magic_stones == (1 if action == 0 else 0) and g.medicine == (1 if action == 2 else 0), "Action item reward " + str(action))
		var power: int = g.power
		g.choose_action(action)
		check(g.power == power, "Repeated action input ignored")
		g.advance_phase(2.6)
		g.resolve_night()
		check(g.survived == 1, "One survival credit per night")
		g.free()
	g = fresh(); night_action(g, 1)
	check(g.lost and g.survived == 0 and g.phase == "lost", "Low power with no item loses")
	g.free()
	g = fresh(); g.power = 2; night_action(g, 1)
	check(g.survived == 1 and g.power == 3, "Exact threshold survives")
	g.free()
	g = fresh(); g.magic_stones = 1; g.medicine = 1; night_action(g, 1)
	check(g.survived == 1 and g.magic_stones == 0 and g.medicine == 1, "Magic stone is consumed before medicine")
	g.next_day(); night_action(g, 1)
	check(g.survived == 2 and g.medicine == 0, "Medicine rescue consumed once")
	g.next_day(); night_action(g, 1)
	check(g.lost and not g.won and g.survived == 2, "Third-night defeat is not a win")
	g.free()
	g = fresh()
	for day in range(3):
		g.branches = 3; g.rocks = 4; g.ropes = 3; g.craft_recipe(0)
		night_action(g, 1)
		if day < 2: g.next_day()
	check(g.won and g.survived == 3 and g.night == 3 and g.fullness == 0, "Three-night weapons victory; fullness warns only")
	g.next_day()
	check(g.night == 3 and g.phase == "won", "No fourth night after winning")
	g.free()
	g = fresh()
	for action in [0, 2, 0]:
		night_action(g, action)
		g.next_day()
	check(g.won and g.magic_stones == 0 and g.medicine == 0, "Full three-night item-assisted victory")
	g.free()
	g = fresh(); g.branches = 3; g.rocks = 4; g.ropes = 3
	for attempt in range(1000): g.collect_item(0)
	check(g.branches + g.rocks + g.ropes == 10 and not g.items[0].taken, "Full bag rejects 1000 repeated pickups")
	g.drop_material(0)
	check(g.branches == 2 and g.items[-1].dropped, "Drop preserves resource")
	g.collect_item(g.items.size() - 1)
	check(g.branches == 3, "Re-pickup dropped resource")
	g.craft_recipe(0); g.collect_item(0)
	var kept: int = g.branches
	night_action(g, 1); g.next_day()
	check(g.branches == kept and g.weapons.size() == 1 and not g.items[0].taken and g.items.size() == 16, "Dawn restocks originals and preserves carried gear")
	g.start_night(); var old: int = g.branches; g.collect_item(0); g.craft_recipe(0)
	check(g.branches == old and g.weapons.size() == 1, "Night blocks collecting and crafting")
	g.free()
	g = fresh()
	for value in [0, 20, 40, 60, 100]:
		g.fullness = value
		check(not g.food_check().is_empty(), "Fullness warning " + str(value))
	check(not g.walkable(Vector2(1000, 400)) and not g.walkable(Vector2(300, 550)), "Lake and cabin collision")
	var origin: Vector2 = g.player; g.move_player(Vector2(1, 1), 0.1)
	check(absf(g.player.distance_to(origin) - g.SPEED * 0.1) < 0.01, "Diagonal movement speed")
	g.free()
	g = fresh()
	g.advance_day(89.5)
	check(g.phase == "day" and g.clock_text() == "00:01", "Countdown stays in daylight until deadline")
	g.paused = true; g.advance_day(50)
	check(g.day_time == 89.5, "Esc pause freezes daylight clock")
	g.paused = false; g.inventory = true; g.crafting = true; g.dialog = "test"
	g.advance_day(0.5)
	check(g.phase == "dusk" and not g.inventory and not g.crafting and g.dialog.is_empty(), "Automatic night closes daytime panels at deadline")
	g.advance_day(100)
	check(g.phase == "dusk" and g.night == 1 and g.fullness == 100, "Clock cannot trigger duplicate night or action cost")
	g.advance_phase(2.1); g.choose_action(0); g.advance_phase(2.6); g.next_day()
	check(g.phase == "day" and g.day_time == 0 and g.clock_text() == "01:30", "Morning resets countdown to 90 seconds")
	g.inventory = true; g.advance_day(5)
	check(g.day_time == 5, "Backpack does not pause daylight")
	g.inventory = false; g.crafting = true; g.advance_day(5)
	check(g.day_time == 10, "Crafting does not pause daylight")
	g.free()
	print("RESULT: ", checks, " checks, ", failures, " failures")
	quit(failures)
