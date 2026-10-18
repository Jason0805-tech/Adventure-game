extends Node2D
# 0.1.3: All visuals are drawn with simple shapes; no external art needed.
const WORLD := Vector2(2200, 1500)
const SPEED := 240.0
@export var day_duration: float = 90.0
var day_time := 0.0
const CAPACITY := 10
var player := Vector2(360, 760)
var camera := Vector2.ZERO
var facing := Vector2.DOWN
var branches := 0
var rocks := 0
var ropes := 0
const RECIPES = [
	["Large stone sword", 3, 4, 3, 4],
	["Short stone knife", 2, 2, 1, 2],
	["Stone axe", 2, 3, 2, 3],
	["Wooden knife", 4, 0, 2, 3],
	["Wooden sword", 5, 1, 2, 4],
	["Amazing stone sword", 0, 1, 0, 1]
]
var weapons: Array[String] = []
var power := 0
var fullness := 100
var magic_stones := 0
var medicine := 0
var night := 1
var survived := 0
var phase := "day"
var phase_time := 0.0
var lost := false
var crafting := false
var result_text := ""
var action_text := ""
var buttons: Array[Dictionary] = []
var sword := false
var quest := false
var won := false
var paused := false
var inventory := false
var dialog := ""
var message := "Survive three nights. Daylight lasts 90 seconds. Watch the sun and timer."
var message_time := 8.0
var elapsed := 0.0
var obstacles: Array[Rect2] = []
var trees: Array[Vector2] = []
var items: Array[Dictionary] = []
var npc_home := Vector2(455, 725)
var npc_scout := Vector2(1280, 970)
var npc_position := Vector2(1280, 970)
var gate := Vector2(2030, 280)
var pond := Rect2(920, 350, 330, 230)
var cabin := Rect2(240, 490, 220, 145)
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	build_world()
	print("GAME_READY 0.1.3")
	queue_redraw()

func build_world() -> void:
	obstacles = [pond, cabin]
	# Keep the main east/west and north/south paths clear.
	var rng := RandomNumberGenerator.new()
	rng.seed = 10200
	for i in range(115):
		var p := Vector2(rng.randf_range(90, 2110), rng.randf_range(100, 1400))
		if absf(p.y - 760) < 105 or absf(p.x - 1700) < 95:
			continue
		if p.distance_to(player) < 270 or p.distance_to(npc_home) < 180:
			continue
		if p.distance_to(gate) < 210 or p.distance_to(npc_scout) < 170:
			continue
		if pond.grow(65).has_point(p) or cabin.grow(70).has_point(p):
			continue
		trees.append(p)
		obstacles.append(Rect2(p - Vector2(20, 12), Vector2(40, 38)))
	for p in [Vector2(590, 715), Vector2(670, 810), Vector2(770, 695), Vector2(880, 825), Vector2(1050, 730), Vector2(1430, 820)]:
		add_item(p, "branch")
	for p in [Vector2(620, 820), Vector2(740, 780), Vector2(840, 710), Vector2(1120, 800), Vector2(1520, 710)]:
		add_item(p, "rock")
	for p in [Vector2(555, 800), Vector2(690, 705), Vector2(950, 735), Vector2(1180, 710), Vector2(1620, 820)]:
		add_item(p, "rope")


func add_item(p: Vector2, kind: String) -> void:
	items.append({"pos": p, "kind": kind, "taken": false})

func walkable(p: Vector2) -> bool:
	if p.x < 32 or p.y < 40 or p.x > WORLD.x - 32 or p.y > WORLD.y - 32:
		return false
	var feet := Rect2(p - Vector2(13, 8), Vector2(26, 24))
	for rect in obstacles:
		if feet.intersects(rect):
			return false
	return true

func move_player(direction: Vector2, delta: float) -> void:
	if direction.length() > 0:
		facing = direction.normalized()
	var movement := direction.limit_length() * SPEED * delta
	var next := player + Vector2(movement.x, 0)
	if walkable(next):
		player.x = next.x
	next = player + Vector2(0, movement.y)
	if walkable(next):
		player.y = next.y

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not paused:
		elapsed += dt
		message_time = maxf(0, message_time - dt)
		if phase == "day":
			advance_day(delta)
		elif phase == "dusk" or phase == "encounter":
			advance_phase(delta)
		if phase == "day" and not inventory and not crafting and dialog.is_empty():
			var direction := Vector2.ZERO
			if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
			if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
			if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
			if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
			move_player(direction, dt)
			npc_position = npc_scout + Vector2(sin(elapsed * 0.65) * 55, 0)
	var screen := get_viewport_rect().size
	camera = player - screen * 0.5
	camera.x = clampf(camera.x, 0, maxf(0, WORLD.x - screen.x))
	camera.y = clampf(camera.y, 0, maxf(0, WORLD.y - screen.y))
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key == KEY_R and (won or lost):
		get_tree().reload_current_scene()
		return
	if key == KEY_ESCAPE:
		if not dialog.is_empty(): dialog = ""
		elif inventory: inventory = false
		elif crafting: crafting = false
		elif not won and not lost: paused = not paused
		return
	if paused or won or lost: return
	if phase == "result":
		if key == KEY_ENTER or key == KEY_SPACE: next_day()
		return
	if phase == "choice":
		if key >= KEY_1 and key <= KEY_3: choose_action(key - KEY_1)
		return
	if phase != "day": return
	if not dialog.is_empty():
		if key == KEY_E or key == KEY_SPACE: dialog = ""
		return
	if crafting:
		if key == KEY_C: crafting = false
		elif key >= KEY_1 and key <= KEY_6: craft_recipe(key - KEY_1)
		return
	if key == KEY_B:
		inventory = not inventory
		return
	if inventory: return
	if key == KEY_E: interact()
	if key == KEY_C: crafting = true

func notify(text: String) -> void:
	message = text
	message_time = 5.0

func nearest_target() -> Dictionary:
	var best := 85.0
	var target: Dictionary = {}
	var candidates: Array[Dictionary] = [{"pos": npc_home, "kind": "guide"}, {"pos": npc_position, "kind": "scout"}, {"pos": gate, "kind": "gate"}]
	for i in range(items.size()):
		if not items[i].taken:
			candidates.append({"pos": items[i].pos, "kind": "item", "index": i})
	for candidate in candidates:
		var distance := player.distance_to(candidate.pos)
		if distance < best:
			best = distance
			target = candidate
	return target

func interact() -> void:
	var target := nearest_target()
	if target.is_empty():
		notify("Move closer to a person, resource or exit, then press E.")
		return
	match target.kind:
		"guide":
			quest = true
			dialog = "Rowan - Camp guide\n\nSurvive three nights to escape this forest.\nGather branches, rocks and ropes during the day.\nPress C to craft weapons. Their power adds up.\nNight arrives automatically after 90 seconds.\n\nThe threats need 3, 6 and 9 power.\nA magic stone or medicine can save you once."
		"scout":
			dialog = "Ash - Forest scout\n\nAt night: explore, rest, or look for food.\nExplore gives +2 power and a magic stone.\nRest gives +1 power. Food gives +1 and medicine.\nEvery night costs fullness; check the action cards.\n\nFullness only gives warnings in this version.\nThe timer runs in menus. Esc pauses the game."
		"gate":
			notify("The forest is unsafe. Survive all three nights to escape.")
		"item":
			collect_item(int(target.index))

func collect_item(index: int) -> void:
	if index < 0 or index >= items.size(): return
	if items[index].taken: return
	var kind: String = items[index].kind
	if phase != "day": return
	if branches + rocks + ropes >= CAPACITY:
		notify("Bag full. Press C to craft, or B to drop extra supplies.")
		print("PICKUP_BLOCKED: bag full; items=", branches + rocks + ropes)
		return
	print("PICKUP: ", kind, " at index ", index)
	items[index].taken = true
	match kind:
		"branch": branches += 1
		"rock": rocks += 1
		"rope": ropes += 1
	notify("Picked up: " + item_name(kind))

func craft_recipe(index: int) -> void:
	if phase != "day" or index < 0 or index >= RECIPES.size(): return
	var recipe: Array = RECIPES[index]
	if index == 5 and not weapons.has("Large stone sword"):
		notify("Upgrade needs a large stone sword and one rock.")
		return
	if branches < recipe[1] or rocks < recipe[2] or ropes < recipe[3]:
		notify("Not enough materials. Close crafting and collect more.")
		return
	branches -= recipe[1]
	rocks -= recipe[2]
	ropes -= recipe[3]
	if index == 5: weapons.erase("Large stone sword")
	weapons.append(recipe[0])
	power += recipe[4]
	sword = not weapons.is_empty()
	notify("Crafted " + recipe[0] + ". Total power: " + str(power))
	print("CRAFT: ", recipe[0], " power=", power)

func food_check() -> String:
	if fullness <= 0: return "You are starving! Find food soon."
	if fullness <= 20: return "You are very hungry and uncomfortable."
	if fullness <= 40: return "You are hungry."
	if fullness <= 60: return "You should eat some food soon."
	return "You feel well fed."

func advance_day(dt: float) -> void:
	if paused or phase != "day": return
	day_time = minf(day_time + maxf(0, dt), maxf(1, day_duration))
	if day_time >= maxf(1, day_duration):
		inventory = false
		crafting = false
		dialog = ""
		start_night()

func day_fraction() -> float:
	return clampf(day_time / maxf(1, day_duration), 0, 1)

func clock_text() -> String:
	var seconds := int(ceil(maxf(0, day_duration - day_time)))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func start_night() -> void:
	if phase != "day" or paused or inventory or crafting or not dialog.is_empty(): return
	phase = "dusk"
	phase_time = 0.0
	player = Vector2(360, 760)
	print("NIGHT_START ", night)

func advance_phase(dt: float) -> void:
	if paused: return
	phase_time += dt
	if phase == "dusk" and phase_time >= 2.0:
		phase = "choice"
	elif phase == "encounter" and phase_time >= 2.5:
		resolve_night()

func choose_action(index: int) -> void:
	if phase != "choice" or index < 0 or index > 2: return
	fullness -= 30
	match index:
		0:
			power += 2
			fullness -= 20
			magic_stones += 1
			action_text = "You explored the forest and found a magic stone."
		1:
			power += 1
			fullness -= 5
			action_text = "You rested and regained your strength."
		2:
			power += 1
			fullness += 30
			medicine += 1
			action_text = "You found berries and a dose of medicine."
	fullness = clampi(fullness, 0, 100)
	phase = "encounter"
	phase_time = 0.0
	print("NIGHT_ACTION ", index, " power=", power, " fullness=", fullness)

func resolve_night() -> void:
	if phase != "encounter": return
	var threat := night * 3
	result_text = "Your power kept the danger away."
	if power < threat:
		if magic_stones > 0:
			magic_stones -= 1
			result_text = "A magic stone saved you. One stone was consumed."
		elif medicine > 0:
			medicine -= 1
			result_text = "Medicine healed your injuries. One dose was consumed."
		else:
			lost = true
			phase = "lost"
			result_text = "Something in the dark overwhelmed you."
			print("GAME_OVER night=", night)
			return
	survived += 1
	if survived == 3:
		won = true
		phase = "won"
	else:
		phase = "result"
	print("NIGHT_SURVIVED ", survived)

func next_day() -> void:
	if phase != "result": return
	night += 1
	day_time = 0.0
	phase = "day"
	# Restore only the original resource locations, not dropped duplicates.
	var original: Array[Dictionary] = []
	for item in items:
		if not item.get("dropped", false):
			item.taken = false
			original.append(item)
	items = original
	notify("Morning! Materials have returned. Prepare for night " + str(night) + ".")

func item_name(kind: String) -> String:
	return {"branch": "Branches", "rock": "Rocks", "rope": "Ropes", "crystal": "Blue crystal"}.get(kind, kind)

func drop_material(index: int) -> void:
	if phase != "day" or index < 0 or index > 2: return
	var counts := [branches, rocks, ropes]
	if counts[index] == 0: return
	if index == 0: branches -= 1
	if index == 1: rocks -= 1
	if index == 2: ropes -= 1
	add_item(player, ["branch", "rock", "rope"][index])
	items[-1]["dropped"] = true

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				activate_button(button.id)
				get_viewport().set_input_as_handled()
				return

func activate_button(id: String) -> void:
	if id == "restart" and (won or lost):
		get_tree().reload_current_scene()
		return
	if id == "resume": paused = false; return
	if paused: return
	if id.begins_with("action_"): choose_action(int(id.trim_prefix("action_")))
	elif id.begins_with("craft_") and crafting: craft_recipe(int(id.trim_prefix("craft_")))
	elif id.begins_with("drop_") and inventory: drop_material(int(id.trim_prefix("drop_")))
	elif id == "morning": next_day()
	elif id == "close":
		inventory = false
		crafting = false
		dialog = ""

func label_at(p: Vector2, text: String, size: int = 18, color := Color("e6ecd9")) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func person(p: Vector2, color: Color, title: String, is_player: bool = false) -> void:
	draw_ellipse_shadow(p)
	draw_line(p + Vector2(-6, 7), p + Vector2(-7, 17), Color("1c3039"), 7)
	draw_line(p + Vector2(6, 7), p + Vector2(7, 17), Color("1c3039"), 7)
	draw_rect(Rect2(p - Vector2(13, 19), Vector2(26, 28)), color)
	draw_circle(p + Vector2(0, -28), 11, Color("edc8a0"))
	draw_arc(p + Vector2(0, -29), 11, PI, TAU, 12, Color("27373e"), 5)
	if is_player:
		draw_circle(p + Vector2(0, -28) + facing * 5, 2, Color("27373e"))
		if sword:
			draw_line(p + Vector2(19, 2), p + Vector2(29, -25), Color("d0e3e5"), 5)
	else:
		label_at(p + Vector2(-26, -50), title, 16)

func draw_ellipse_shadow(p: Vector2) -> void:
	var progress := day_fraction()
	var length := 0.32 + absf(progress - 0.5) * 1.5
	var offset := Vector2(lerpf(28, -34, progress), 16)
	draw_set_transform(-camera + p + offset, lerpf(-0.35, 0.35, progress), Vector2(1.0 + length, 0.32))
	draw_circle(Vector2.ZERO, 19, Color(0.025, 0.045, 0.04, 0.28))
	draw_set_transform(-camera)

func _draw() -> void:
	if font == null: return
	var screen := get_viewport_rect().size
	draw_set_transform(-camera)
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color("344e3d"))
	for x in range(0, 2200, 80):
		for y in range(0, 1500, 80):
			if (x / 80 + y / 80) as int % 3 == 0:
				draw_line(Vector2(x + 25, y + 33), Vector2(x + 29, y + 25), Color("486044"), 2)
	draw_rect(Rect2(100, 710, 1930, 100), Color("877c59"))
	draw_rect(Rect2(1655, 230, 90, 1080), Color("877c59"))
	draw_rect(Rect2(1700, 240, 370, 80), Color("877c59"))
	draw_rect(pond.grow(12), Color("668475"))
	draw_rect(pond, Color("326174"))
	for i in range(7):
		var offset := sin(elapsed + i) * 9
		draw_line(pond.position + Vector2(30 + offset, 25 + i * 28), pond.position + Vector2(160 + offset, 25 + i * 28), Color("4b8490"), 2)
	draw_rect(cabin, Color("a78457"))
	draw_colored_polygon(PackedVector2Array([cabin.position + Vector2(-15, 15), cabin.position + Vector2(110, -70), cabin.position + Vector2(235, 15)]), Color("694c42"))
	draw_rect(Rect2(330, 575, 40, 60), Color("443e35"))
	label_at(Vector2(245, 655), "TRAVELERS CAMP", 20)
	label_at(Vector2(1580, 1360), "SOUTHERN WOODS", 22)
	label_at(Vector2(1580, 195), "NORTHERN TRAIL", 22)
	label_at(Vector2(940, 330), "STILLWATER LAKE", 20)
	for tree in trees:
		draw_ellipse_shadow(tree)
		draw_rect(Rect2(tree - Vector2(9, 10), Vector2(18, 40)), Color("665a40"))
		draw_circle(tree + Vector2(0, -24), 32, Color("254637"))
		draw_circle(tree + Vector2(-10, -39), 23, Color("3e6246"))
	for item in items:
		if item.taken: continue
		var p: Vector2 = item.pos
		match item.kind:
			"branch":
				draw_line(p + Vector2(-11, 8), p + Vector2(10, -9), Color("d3ab75"), 5)
				draw_line(p, p + Vector2(-1, -12), Color("d3ab75"), 3)
			"rock": draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 6), p + Vector2(-7, -8), p + Vector2(7, -11), p + Vector2(13, 7)]), Color("b3c0bd"))
			"rope":
				draw_arc(p, 9, 0, TAU, 20, Color("ced088"), 4)
			"crystal":
				p.y += sin(elapsed * 2) * 4
				draw_circle(p, 24, Color(0.35, 0.8, 0.85, 0.12))
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -17), p + Vector2(11, 0), p + Vector2(0, 17), p + Vector2(-11, 0)]), Color("82d9df"))
	draw_rect(Rect2(gate - Vector2(52, 80), Vector2(20, 110)), Color("a7b4a0"))
	draw_rect(Rect2(gate + Vector2(32, -80), Vector2(20, 110)), Color("a7b4a0"))
	draw_rect(Rect2(gate - Vector2(52, 90), Vector2(104, 20)), Color("b8c6af"))
	draw_rect(Rect2(gate - Vector2(30, 70), Vector2(60, 95)), Color(0.4, 0.8, 0.8, 0.35 if won else 0.08))
	label_at(gate + Vector2(-40, -106), "FOREST GATE", 20)
	person(npc_home, Color("d7a454"), "Rowan")
	person(npc_position, Color("b6a5cd"), "Ash")
	person(player, Color("7ac8c1"), "", true)
	var target := nearest_target()
	if not target.is_empty() and dialog.is_empty() and not inventory and not crafting and phase == "day":
		var text := "E  Talk"
		if target.kind == "gate": text = "E  Open gate"
		if target.kind == "item": text = "E  Pick up " + item_name(items[int(target.index)].kind)
		label_at(player + Vector2(-40, -66), text, 18, Color("fff0b5"))
	draw_set_transform(Vector2.ZERO)
	draw_survival_ui(screen)

func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
	draw_rect(rect, Color("476859") if enabled else Color("2d4039"))
	label_at(rect.position + Vector2(15, rect.size.y * 0.5 + 6), text, 17, Color("f2edda") if enabled else Color("8e9d93"))
	if enabled: buttons.append({"rect": rect, "id": id})

func draw_survival_ui(screen: Vector2) -> void:
	buttons.clear()
	var darkness := 0.0
	if phase == "dusk": darkness = lerpf(0.35, 0.72, minf(phase_time / 2.0, 1.0))
	elif phase != "day": darkness = 0.72
	if won: darkness = 0.22
	if phase == "day":
		var t := day_fraction()
		var dusk := smoothstep(0.55, 1.0, t)
		var morning := 1.0 - smoothstep(0.0, 0.35, t)
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.96, 0.67, 0.35, morning * 0.07 + dusk * 0.13))
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.09, 0.23, dusk * 0.35))
	if darkness > 0:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.025, 0.045, 0.13, darkness))
		# Lantern glow around the player and eyes watching from the woods.
		for i in range(5, 0, -1):
			draw_circle(player - camera, 22 + i * 17, Color(1.0, 0.72, 0.28, 0.025))
		if phase == "encounter":
			for x in [170, 290, 820, 945]:
				draw_circle(Vector2(x, 240 + (x % 3) * 60), 3, Color("d99562"))
				draw_circle(Vector2(x + 12, 240 + (x % 3) * 60), 3, Color("d99562"))
	draw_rect(Rect2(0, 0, screen.x, 118), Color("172c2b"))
	label_at(Vector2(24, 32), "FOREST WANDERER", 25)
	label_at(Vector2(335, 31), "0.1.3  /  THREE NIGHTS", 16, Color("a0b7a7"))
	label_at(Vector2(screen.x - 265, 32), ("NIGHT IN " + clock_text()) if phase == "day" else ("NIGHT " + str(night)), 22, Color("f0d192"))
	label_at(Vector2(24, 63), "Survived %d / 3   |   %s %d   |   Threat %d   |   Power %d   |   Fullness %d / 100" % [survived, "Day" if phase == "day" else "Night", night, night * 3, power, fullness], 19)
	label_at(Vector2(24, 94), "Branches %d   Rocks %d   Ropes %d   |   Bag %d/10   |   Magic stones %d   Medicine %d" % [branches, rocks, ropes, branches + rocks + ropes, magic_stones, medicine], 17)
	var map_pos := Vector2(screen.x - 180, 136)
	draw_rect(Rect2(map_pos, Vector2(156, 108)), Color("1c3530"))
	var map_scale := Vector2(156, 108) / WORLD
	draw_line(map_pos + Vector2(100, 760) * map_scale, map_pos + Vector2(2030, 760) * map_scale, Color("877c59"), 3)
	draw_line(map_pos + Vector2(1700, 230) * map_scale, map_pos + Vector2(1700, 1310) * map_scale, Color("877c59"), 3)
	draw_circle(map_pos + npc_home * map_scale, 4, Color("e5c47c"))
	draw_circle(map_pos + player * map_scale, 4, Color.WHITE)
	label_at(map_pos + Vector2(0, 129), "White: you / Gold: camp", 12)
	draw_rect(Rect2(0, screen.y - 46, screen.x, 46), Color("172c2b"))
	label_at(Vector2(24, screen.y - 17), "WASD / Arrows: Move    E: Interact    B: Bag    C: Craft    Esc: Pause", 17)
	var modal := inventory or crafting or paused or not dialog.is_empty() or phase != "day"
	if not modal:
		var time_name := "MORNING"
		if day_fraction() >= 0.35: time_name = "MIDDAY"
		if day_fraction() >= 0.7: time_name = "SUNSET - NIGHT APPROACHES"
		label_at(Vector2(24, 149), time_name, 16)
		label_at(Vector2(24, 176), "Night in " + clock_text(), 21)
		# A small sky strip shows the sun crossing from dawn to dusk.
		var sky := Color("819d9c").lerp(Color("c88861"), smoothstep(0.55, 1.0, day_fraction()))
		draw_rect(Rect2(24, 193, 225, 32), sky)
		draw_circle(Vector2(37 + day_fraction() * 198, 217 - sin(day_fraction() * PI) * 15), 7, Color("fff0b4"))
	if message_time > 0 and not modal:
		draw_rect(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("233a32"))
		label_at(Vector2(34, screen.y - 72), message, 17)
	if not modal: return
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.06, 0.07, 0.38))
	var base := screen * 0.5 - Vector2(360, 265)
	draw_rect(Rect2(base, Vector2(720, 530)), Color("203b36"))
	if paused:
		label_at(base + Vector2(35, 70), "PAUSED", 32)
		label_at(base + Vector2(35, 125), "The night and all actions are paused.", 20)
		label_at(base + Vector2(35, 175), "No save system yet. Closing resets this run.", 18)
		ui_button(Rect2(base + Vector2(35, 435), Vector2(220, 48)), "Esc  Resume", "resume")
	elif crafting:
		label_at(base + Vector2(30, 40), "CRAFT WEAPONS", 25)
		label_at(base + Vector2(30, 72), "Branches %d / Rocks %d / Ropes %d   |   Power %d" % [branches, rocks, ropes, power], 18)
		for i in range(RECIPES.size()):
			var recipe: Array = RECIPES[i]
			var y := 91 + i * 52
			var cost := "%d branches / %d rocks / %d ropes" % [recipe[1], recipe[2], recipe[3]]
			if i == 5: cost = "Large stone sword + 1 rock (4 -> 5 power)"
			label_at(base + Vector2(30, y + 17), str(i + 1) + ". " + recipe[0] + "   +" + str(recipe[4]) + " power", 18)
			label_at(base + Vector2(30, y + 37), cost, 14, Color("b5c7b9"))
			var enough: bool = branches >= recipe[1] and rocks >= recipe[2] and ropes >= recipe[3]
			if i == 5: enough = enough and weapons.has("Large stone sword")
			ui_button(Rect2(base + Vector2(570, y), Vector2(118, 39)), "Craft", "craft_" + str(i), enough)
		if message_time > 0: label_at(base + Vector2(30, 430), message, 16)
		ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "C / Esc  Close", "close")
	elif inventory:
		label_at(base + Vector2(30, 42), "BACKPACK - %d / 10 materials" % (branches + rocks + ropes), 25)
		for i in range(3):
			label_at(base + Vector2(30, 99 + i * 44), ["Branches", "Rocks", "Ropes"][i] + " x " + str([branches, rocks, ropes][i]), 20)
			ui_button(Rect2(base + Vector2(555, 73 + i * 44), Vector2(130, 35)), "Drop 1", "drop_" + str(i))
		label_at(base + Vector2(30, 232), "Power %d   |   Fullness %d / 100   |   Stones %d   Medicine %d" % [power, fullness, magic_stones, medicine], 18)
		label_at(base + Vector2(30, 268), "WEAPONS (power is cumulative)", 17)
		var counts := {}
		for weapon in weapons: counts[weapon] = counts.get(weapon, 0) + 1
		var row := 0
		for weapon in counts:
			label_at(base + Vector2(30 + (row % 2) * 340, 302 + (row / 2) * 30), weapon + " x " + str(counts[weapon]), 16)
			row += 1
		if weapons.is_empty(): label_at(base + Vector2(30, 302), "None. Press C after closing to craft.", 17)
		label_at(base + Vector2(30, 423), food_check() + " (Warnings only.)", 17)
		ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "B / Esc  Close", "close")
	elif not dialog.is_empty():
		var lines := dialog.split("\n")
		for i in range(lines.size()): label_at(base + Vector2(30, 45 + i * 37), lines[i], 24 if i == 0 else 19)
		ui_button(Rect2(base + Vector2(30, 463), Vector2(250, 42)), "E / Space  Continue", "close")
	elif phase == "dusk":
		label_at(base + Vector2(35, 85), "NIGHT " + str(night) + " IS FALLING", 30)
		label_at(base + Vector2(35, 160), "You return to camp as the forest grows dark.", 21)
		label_at(base + Vector2(35, 225), "Tonight's threat: %d   |   Your power: %d" % [night * 3, power], 21)
		label_at(base + Vector2(35, 325), "Choose how to spend the night...", 19)
	elif phase == "choice":
		label_at(base + Vector2(30, 45), "NIGHT %d / 3 - CHOOSE ONE ACTION" % night, 25)
		label_at(base + Vector2(30, 82), "Threat %d | Power %d | Fullness %d/100" % [night * 3, power, fullness], 19)
		ui_button(Rect2(base + Vector2(30, 112), Vector2(660, 52)), "1  EXPLORE THE FOREST", "action_0")
		label_at(base + Vector2(45, 189), "+2 power, +1 magic stone. Total fullness cost: 50.", 18)
		ui_button(Rect2(base + Vector2(30, 217), Vector2(660, 52)), "2  REST", "action_1")
		label_at(base + Vector2(45, 294), "+1 power. Total fullness cost: 35.", 18)
		ui_button(Rect2(base + Vector2(30, 322), Vector2(660, 52)), "3  LOOK FOR FOOD", "action_2")
		label_at(base + Vector2(45, 399), "+1 power, +1 medicine. Berries offset the nightly 30 cost.", 18)
		label_at(base + Vector2(30, 468), "If power is too low: use a magic stone, then medicine.", 17)
		label_at(base + Vector2(30, 498), "Fullness gives warnings only in this version.", 16, Color("b5c7b9"))
	elif phase == "encounter":
		label_at(base + Vector2(35, 75), "SOMETHING MOVES IN THE DARK...", 27)
		label_at(base + Vector2(35, 145), action_text, 20)
		label_at(base + Vector2(35, 205), "Power %d vs threat %d" % [power, night * 3], 24)
		label_at(base + Vector2(35, 270), "Fullness %d/100 - " % fullness + food_check(), 19)
		label_at(base + Vector2(35, 360), "The danger draws closer...", 20)
	else:
		var title := "NIGHT %d SURVIVED" % night
		if won: title = "THREE NIGHTS SURVIVED - YOU WIN!"
		if lost: title = "GAME OVER - NIGHT " + str(night)
		label_at(base + Vector2(35, 70), title, 27)
		label_at(base + Vector2(35, 140), result_text, 19)
		label_at(base + Vector2(35, 200), "Power %d / Threat %d   |   Fullness %d/100" % [power, night * 3, fullness], 20)
		label_at(base + Vector2(35, 250), "Magic stones left: %d   |   Medicine left: %d" % [magic_stones, medicine], 19)
		label_at(base + Vector2(35, 300), food_check(), 19)
		if won:
			label_at(base + Vector2(35, 365), "Dawn breaks. You leave the forest safely.", 21)
		elif lost:
			label_at(base + Vector2(35, 365), "Craft more weapons, or choose an action that gives an item.", 18)
		else:
			label_at(base + Vector2(35, 365), "Morning brings fresh materials. Your gear stays with you.", 18)
		if won or lost:
			ui_button(Rect2(base + Vector2(35, 440), Vector2(240, 48)), "R  New run", "restart")
		else:
			ui_button(Rect2(base + Vector2(35, 440), Vector2(340, 48)), "Enter  Prepare for night " + str(night + 1), "morning")
