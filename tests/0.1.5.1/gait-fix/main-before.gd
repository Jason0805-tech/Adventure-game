extends Node2D
# 0.1.5.1: Unified loose oil-painted art based on the approved scene.
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
var cabin := Rect2(240, 520, 220, 115)
var font: Font
var art: Array[Texture2D] = []
var traveler_art: Array[Texture2D] = []
var resource_art: Array[Texture2D] = []
var pond_art: Array[Texture2D] = []
var variant_art: Array[Texture2D] = []
var equipment_art: Array[Texture2D] = []
var blend_art: Array[Texture2D] = []
var npc_art: Array[Texture2D] = []
var pools: Array[Rect2] = []
var pond_colliders: Array[PackedVector2Array] = []
var shrubs: Array[Vector2] = []
var show_collision := false
var foot_anchors: Dictionary = {}
var tree_styles: Dictionary = {}
var meadow: Texture2D
var ground_details: Array[Dictionary] = []
var moving := false
var walk_art: Array[Texture2D] = []
var walk_scales: Dictionary = {}
var walk_distance := 0.0
const WALK_STRIDE := 128.0


func visible_bounds(part: Image) -> Rect2i:
	# Fit to visible paint, not nearly transparent color padding from the atlas.
	# Preserve original pixels and feathered edges inside a six-pixel safety margin.
	part.convert(Image.FORMAT_RGBA8)
	var bytes := part.get_data()
	var width := part.get_width()
	var height := part.get_height()
	var left := width
	var top := height
	var right := -1
	var bottom := -1
	for y in range(0, height, 2):
		for x in range(0, width, 2):
			if bytes[(y * width + x) * 4 + 3] >= 32:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < 0: return Rect2i(0, 0, width, height)
	left = maxi(0, left - 6)
	top = maxi(0, top - 6)
	right = mini(width, right + 8)
	bottom = mini(height, bottom + 8)
	return Rect2i(left, top, right - left, bottom - top)

func load_grid(path: String, columns: int, rows: int, row_cuts: Array = [], column_cuts: Array = []) -> Array[Texture2D]:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(path))
	var textures: Array[Texture2D] = []
	for row in range(rows):
		for col in range(columns):
			var x := int(float(col) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col])
			var y := int(float(row) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row]) * sheet.get_height())
			var right := int(float(col + 1) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col + 1])
			var bottom := int(float(row + 1) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row + 1]) * sheet.get_height())
			var part := sheet.get_region(Rect2i(x, y, right - x, bottom - y))
			textures.append(ImageTexture.create_from_image(part.get_region(visible_bounds(part))))
	return textures

func load_art() -> void:
	art = load_grid("res://assets/environment.png", 3, 2, [0.0, 552.0/1024, 1.0], [[0,520,1024,1536],[0,499,1024,1536]])
	traveler_art = load_grid("res://assets/traveler-directions.png", 4, 2)
	resource_art = load_grid("res://assets/materials.png", 3, 3, [0.0, 0.36, 0.67, 1.0])
	pond_art = load_grid("res://assets/ponds.png", 3, 1, [], [[0,607,1208,1774]])
	variant_art = load_grid("res://assets/tree-variants.png", 3, 2, [0.0, 624.0/1024, 1.0], [[0,512,1024,1536],[0,516,1024,1536]])
	equipment_art = load_grid("res://assets/equipment.png", 4, 2)
	blend_art = load_grid("res://assets/ground-blends.png", 3, 2, [], [[0,512,1024,1536],[0,522,1024,1536]])
	npc_art = load_grid("res://assets/npcs.png", 2, 2)
	walk_art.clear()
	for direction in ["down", "left", "right", "up"]:
		var cuts := [[0,368,727,1086,1448,1810,2172]] if direction == "left" else []
		var frames := load_grid("res://assets/walk-" + direction + ".png", 6, 1, [], cuts)
		var mean_height := 0.0
		for frame in frames: mean_height += frame.get_height() / 6.0
		for frame in frames: walk_scales[frame] = 75.0 / mean_height
		walk_art.append_array(frames)
	for texture in traveler_art + npc_art + art + variant_art + walk_art:
		var pixels := texture.get_image()
		var sole_y := pixels.get_height() - 1
		for y in range(pixels.get_height() - 1, -1, -1):
			var solid := false
			for x in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a > 0.5:
					solid = true
					break
			if solid:
				sole_y = y
				break
		var total := 0.0
		var weighted_x := 0.0
		for y in range(maxi(0, sole_y - int(pixels.get_height() * 0.08)), sole_y + 1):
			for x in range(pixels.get_width()):
				var alpha := pixels.get_pixel(x, y).a
				if alpha > 0.5:
					total += alpha
					weighted_x += (x + 0.5) * alpha
		# Walking pivots use the torso, so alternating boots cannot drag the body sideways.
		if texture in walk_art:
			total = 0.0
			weighted_x = 0.0
			for y in range(int(pixels.get_height() * 0.3), int(pixels.get_height() * 0.65)):
				for x in range(pixels.get_width()):
					var alpha := pixels.get_pixel(x, y).a
					if alpha > 0.5:
						total += alpha
						weighted_x += (x + 0.5) * alpha
		foot_anchors[texture] = Vector2(weighted_x / total if total > 0 else pixels.get_width() * 0.5, sole_y + 1)
	meadow = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
	# Stable sparse decals bridge the painted base and object feet without tiling.
	ground_details.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 15015
	for i in range(65):
		var position := Vector2(rng.randf_range(70, 2120), rng.randf_range(90, 1420))
		if absf(position.y - 760) < 90 or absf(position.x - 1700) < 85: continue
		ground_details.append({"p": position, "size": Vector2(rng.randf_range(70, 130), rng.randf_range(35, 65)), "variant": i % 2})

func ground_patch(index: int, center: Vector2, size: Vector2, opacity: float = 1.0) -> void:
	if not blend_art.is_empty():
		draw_texture_rect(blend_art[index], Rect2(center - size * 0.5, size), false, Color(1, 1, 1, opacity))

func varied_tree(p: Vector2, faded: bool) -> void:
	var seed_value := absi(int(p.x * 17 + p.y * 31))
	var variant: int = tree_styles.get(p, seed_value % 6)
	var tex: Texture2D = art[variant] if variant < 3 else variant_art[variant - 3]
	var height := 148.0 + seed_value % 39
	var warmth := float(seed_value % 11) / 180.0
	var tint := Color(1.0 - warmth * 0.35, 1.0 - warmth * 0.15, 1.0 - warmth, 0.42 if faded else 1.0)
	# Mirror around the shared ground anchor, never via a negative texture rectangle.
	draw_set_transform(-camera + p, 0, Vector2(-1 if seed_value % 2 else 1, 1))
	draw_sprite(tex, Vector2(0, 5), height, tint)
	draw_set_transform(-camera)

func sprite_rect(tex: Texture2D, foot: Vector2, height: float) -> Rect2:
	var scale := height / tex.get_height()
	var width := tex.get_width() * scale
	var pivot: Vector2 = foot_anchors.get(tex, Vector2(tex.get_width() * 0.5, tex.get_height()))
	return Rect2(foot - pivot * scale, Vector2(width, height))

func draw_sprite(tex: Texture2D, foot: Vector2, height: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(tex, sprite_rect(tex, foot, height), false, tint)

func painted_sprite(index: int, foot: Vector2, height: float, _flip: bool = false, tint: Color = Color.WHITE) -> void:
	if not art.is_empty(): draw_sprite(art[index], foot, height, tint)

func direction_index(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 1 if direction.x < 0 else 2
	return 3 if direction.y < 0 else 0

func feet_rect(p: Vector2) -> Rect2:
	return Rect2(p - Vector2(11, 9), Vector2(22, 14))

func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])

func paper_panel(rect: Rect2, fill: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = Color("a68e62")
	style.shadow_color = Color(0.02, 0.08, 0.09, 0.18)
	style.shadow_size = 4
	draw_style_box(style, rect)


func _ready() -> void:
	font = ThemeDB.fallback_font
	load_art()
	build_world()
	print("GAME_READY 0.1.5.1")
	queue_redraw()

func build_world() -> void:
	tree_styles.clear()
	trees.clear()
	items.clear()
	shrubs.clear()
	pond_colliders.clear()
	pools = [pond, Rect2(550, 1080, 220, 150), Rect2(1380, 380, 210, 135)]
	obstacles = [cabin, Rect2(gate + Vector2(-57, -19), Vector2(29, 49)), Rect2(gate + Vector2(29, -19), Vector2(29, 49))]
	for pool in pools:
		var poly := PackedVector2Array()
		for i in range(24):
			var angle := TAU * i / 24.0
			poly.append(pool.get_center() + Vector2(cos(angle), sin(angle)) * pool.size * Vector2(0.46, 0.44))
		pond_colliders.append(poly)
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
		var by_water := false
		for pool in pools:
			if pool.grow(80).has_point(p): by_water = true
		if by_water or cabin.grow(95).has_point(p): continue
		var usage := [0, 0, 0, 0, 0, 0]
		for neighbor in trees:
			if neighbor.distance_to(p) < 280:
				usage[int(tree_styles[neighbor])] += 1
		var variant := i % 6
		for k in range(6):
			var candidate := (i + k) % 6
			if usage[candidate] < usage[variant]: variant = candidate
		tree_styles[p] = variant
		trees.append(p)
		obstacles.append(Rect2(p - Vector2(16, 13), Vector2(32, 21)))
		if i % 4 == 0:
			var shrub := p + Vector2(65, 24)
			shrubs.append(shrub)
			obstacles.append(Rect2(shrub - Vector2(19, 13), Vector2(38, 23)))
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
	var feet := feet_rect(p)
	for rect in obstacles:
		if feet.intersects(rect): return false
	for npc in [npc_home, npc_position]:
		if feet.intersects(feet_rect(npc)): return false
	var polygon := rect_polygon(feet)
	for collider in pond_colliders:
		if not Geometry2D.intersect_polygons(polygon, collider).is_empty(): return false
	return true

func move_player(direction: Vector2, delta: float) -> void:
	if direction.length() > 0: facing = direction.normalized()
	var movement := direction.limit_length() * SPEED * delta
	# Small steps prevent crossing a thin trunk even during a long frame.
	var steps := maxi(1, ceili(movement.length() / 5.0))
	var step := movement / steps
	for i in range(steps):
		var next := player + Vector2(step.x, 0)
		if walkable(next): player.x = next.x
		next = player + Vector2(0, step.y)
		if walkable(next): player.y = next.y

func update_walk(distance: float) -> void:
	moving = distance > 0.1
	if moving: walk_distance = fposmod(walk_distance + distance, WALK_STRIDE)

func walk_frame() -> int:
	return mini(5, int(walk_distance / WALK_STRIDE * 6.0))

func _process(delta: float) -> void:
	moving = false
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
			var previous := player
			move_player(direction, dt)
			update_walk(player.distance_to(previous))
			var scout_next := npc_scout + Vector2(sin(elapsed * 0.65) * 55, 0)
			if not feet_rect(scout_next).intersects(feet_rect(player)): npc_position = scout_next
	var screen := get_viewport_rect().size
	camera = player - screen * Vector2(0.5, 0.67)
	camera.x = clampf(camera.x, 0, maxf(0, WORLD.x - screen.x))
	camera.y = clampf(camera.y, 0, maxf(0, WORLD.y - screen.y))
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key == KEY_F3:
		show_collision = not show_collision
		return
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

func label_at(p: Vector2, text: String, size: int = 18, color := Color("35483d")) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func person(p: Vector2, _color: Color, title: String, is_player: bool = false) -> void:
	draw_ellipse_shadow(p)
	if is_player and not traveler_art.is_empty():
		var frame := direction_index(facing)
		if moving and not walk_art.is_empty():
			var texture := walk_art[frame * 6 + walk_frame()]
			draw_sprite(texture, p, texture.get_height() * walk_scales[texture])
		else:
			draw_sprite(traveler_art[frame], p, 75)
		draw_arc(p + Vector2(0, -2), 15, 0.05, PI - 0.05, 20, Color(0.98, 0.88, 0.6, 0.72), 1.5, true)
		if sword and not equipment_art.is_empty():
			var weapon_index := 0
			if not weapons.is_empty():
				for i in range(RECIPES.size()):
					if RECIPES[i][0] == weapons[-1]: weapon_index = i
			var side := -1.0 if facing.x < 0 else 1.0
			draw_sprite(equipment_art[weapon_index], p + Vector2(side * 21, -6), 35)
	elif not npc_art.is_empty():
		var frame := 0 if title == "Rowan" else 1
		if player.y < p.y - 32 and player.distance_to(p) < 110: frame += 2
		draw_sprite(npc_art[frame], p, 76)
		label_at(p + Vector2(-26, -81), title, 16, Color("304c3c"))

func draw_ellipse_shadow(p: Vector2) -> void:
	var progress := day_fraction()
	var cast := Vector2(lerpf(18, -18, progress), 4)
	var daylight := phase == "day" or phase == "dusk"
	# Irregular painted outline, attached to the feet independently of facing.
	var outline := PackedVector2Array()
	for i in range(28):
		var angle := TAU * i / 28.0
		var irregular := 1.0 + sin(i * 2.3) * 0.045
		outline.append(p + cast * 0.5 + Vector2(cos(angle) * (23 + absf(cast.x) * 0.5), sin(angle) * 8) * irregular)
	draw_colored_polygon(outline, Color(0.08, 0.17, 0.16, 0.30 if daylight else 0.17))
	ground_patch(3, p + cast * 0.4, Vector2(49, 20), 0.35)
	var contact := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		contact.append(p + Vector2(cos(angle) * 13, sin(angle) * 4.5))
	draw_colored_polygon(contact, Color(0.055, 0.12, 0.11, 0.26))

func draw_collision_overlay() -> void:
	for rect in obstacles: draw_rect(rect, Color(1, 0.47, 0.32, 0.85), false, 2)
	for polygon in pond_colliders:
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(0.35, 0.82, 1, 0.9), 2, true)
	for npc in [npc_home, npc_position]: draw_rect(feet_rect(npc), Color("efb850"), false, 2)
	draw_rect(feet_rect(player), Color("b4ffbd"), false, 2)
	draw_circle(player, 3, Color.WHITE)

func _draw() -> void:
	if font == null: return
	var screen := get_viewport_rect().size
	draw_set_transform(-camera)
	if meadow != null:
		draw_texture_rect(meadow, Rect2(Vector2.ZERO, WORLD), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, WORLD), Color("71927b"))
	for detail in ground_details:
		ground_patch(detail.variant, detail.p, detail.size, 0.36)
	for tree in trees:
		ground_patch(0 if int(tree.x) % 2 else 1, tree + Vector2(0, 3), Vector2(94, 39), 0.58)
	ground_patch(2, Vector2(350, 634), Vector2(251, 65), 0.68)
	ground_patch(4, Vector2(354, 683), Vector2(113, 65), 0.46)
	for i in range(pools.size()):
		ground_patch(0, pools[i].get_center(), pools[i].size + Vector2(19, 17), 0.25)
		if not pond_art.is_empty(): draw_texture_rect(pond_art[i], pools[i], false)
		var center := pools[i].get_center()
		for wave in range(3):
			var start := center + Vector2(-35 + wave * 27 + sin(elapsed + wave) * 3, -12 + wave * 14)
			draw_line(start, start + Vector2(17, -1), Color(0.78, 0.94, 0.87, 0.21), 1.5, true)
	label_at(Vector2(1580, 1360), "SOUTHERN WOODS", 19, Color("304c3c"))
	label_at(Vector2(1580, 195), "NORTHERN TRAIL", 19, Color("304c3c"))
	label_at(Vector2(940, 325), "STILLWATER LAKE", 18, Color("304c3c"))
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if item.taken: continue
		var p: Vector2 = item.pos
		var row := 0 if item.kind == "branch" else (1 if item.kind == "rock" else 2)
		if not resource_art.is_empty():
			var tex := resource_art[row * 3 + i % 3]
			var size := Vector2(36, 28) if row == 0 else Vector2(31, 25)
			ground_patch(3, p + Vector2(1, 6), Vector2(31, 13), 0.22)
			draw_texture_rect(tex, Rect2(p - size * 0.5, size), false)
	# Depth-sort tall objects by their feet so travelers can pass behind tree canopies.
	var scenery: Array[Dictionary] = []
	for tree in trees: scenery.append({"p": tree, "kind": "tree"})
	for shrub in shrubs: scenery.append({"p": shrub, "kind": "shrub"})
	scenery.append({"p": Vector2(350, 635), "kind": "cabin"})
	scenery.append({"p": gate + Vector2(0, 30), "kind": "gate"})
	scenery.append({"p": npc_home, "kind": "Rowan"})
	scenery.append({"p": npc_position, "kind": "Ash"})
	scenery.append({"p": player, "kind": "player"})
	scenery.sort_custom(func(a, b): return a.p.y < b.p.y)
	for entry in scenery:
		var p: Vector2 = entry.p
		match entry.kind:
			"tree":
				draw_ellipse_shadow(p)
				var faded := player.y < p.y and absf(player.x - p.x) < 86 and p.y - player.y < 185
				varied_tree(p, faded)
			"shrub":
				var shrub_index := absi(int(p.x + p.y)) % 4
				var tex: Texture2D = art[3] if shrub_index == 0 else variant_art[shrub_index + 2]
				draw_sprite(tex, p + Vector2(0, 9), 53 + absi(int(p.x)) % 13)
			"cabin": painted_sprite(4, p, 222)
			"gate": painted_sprite(5, p, 132)
			"Rowan": person(p, Color.WHITE, "Rowan")
			"Ash": person(p, Color.WHITE, "Ash")
			"player": person(p, Color.WHITE, "", true)
	label_at(Vector2(254, 665), "TRAVELERS CAMP", 18, Color("304c3c"))
	var target := nearest_target()
	if not target.is_empty() and dialog.is_empty() and not inventory and not crafting and phase == "day":
		var text := "E  Talk"
		if target.kind == "gate": text = "E  Open gate"
		if target.kind == "item": text = "E  Pick up " + item_name(items[int(target.index)].kind)
		label_at(player + Vector2(-40, -91), text, 18, Color("fff0b5"))
	if show_collision: draw_collision_overlay()
	draw_set_transform(Vector2.ZERO)
	draw_survival_ui(screen)
	if show_collision:
		paper_panel(Rect2(270, 125, 570, 31), Color("e9dcb6"), 6)
		label_at(Vector2(283, 147), "F3  COLLISIONS: green = feet / coral = solid / blue = water", 15)

func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
	paper_panel(rect, Color("426d67") if enabled else Color("304743"), 8)
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
	paper_panel(Rect2(12, 8, screen.x - 24, 108), Color("e9dcb6"))
	label_at(Vector2(24, 32), "FOREST WANDERER", 25)
	label_at(Vector2(335, 31), "0.1.5.1  /  THREE NIGHTS", 16, Color("657259"))
	label_at(Vector2(screen.x - 265, 32), ("NIGHT IN " + clock_text()) if phase == "day" else ("NIGHT " + str(night)), 22, Color("875c31"))
	label_at(Vector2(24, 63), "Survived %d / 3   |   %s %d   |   Threat %d   |   Power %d   |   Fullness %d / 100" % [survived, "Day" if phase == "day" else "Night", night, night * 3, power, fullness], 19)
	label_at(Vector2(24, 94), "Branches %d   Rocks %d   Ropes %d   |   Bag %d/10   |   Magic stones %d   Medicine %d" % [branches, rocks, ropes, branches + rocks + ropes, magic_stones, medicine], 17)
	var map_pos := Vector2(screen.x - 180, 136)
	paper_panel(Rect2(map_pos - Vector2(8, 8), Vector2(172, 124)), Color("e6d8b3"))
	var map_scale := Vector2(156, 108) / WORLD
	draw_line(map_pos + Vector2(100, 760) * map_scale, map_pos + Vector2(2030, 760) * map_scale, Color("877c59"), 3)
	draw_line(map_pos + Vector2(1700, 230) * map_scale, map_pos + Vector2(1700, 1310) * map_scale, Color("877c59"), 3)
	draw_circle(map_pos + npc_home * map_scale, 4, Color("e5c47c"))
	draw_circle(map_pos + player * map_scale, 4, Color("28566a"))
	label_at(map_pos + Vector2(0, 129), "Blue: you / Gold: camp", 12)
	paper_panel(Rect2(12, screen.y - 45, screen.x - 24, 38), Color("e9dcb6"), 8)
	label_at(Vector2(24, screen.y - 17), "WASD / Arrows: Move    E: Interact    B: Bag    C: Craft    Esc: Pause    F3: Hitboxes", 17)
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
		paper_panel(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("e6d8b3"), 8)
		label_at(Vector2(34, screen.y - 72), message, 17)
	if not modal: return
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.06, 0.07, 0.38))
	var base := screen * 0.5 - Vector2(360, 265)
	paper_panel(Rect2(base, Vector2(720, 530)), Color("e9dcb6"), 16)
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
			draw_texture_rect(equipment_art[i], Rect2(base + Vector2(29, y + 1), Vector2(33, 39)), false)
			label_at(base + Vector2(73, y + 17), str(i + 1) + ". " + recipe[0] + "   +" + str(recipe[4]) + " power", 18)
			label_at(base + Vector2(73, y + 37), cost, 14, Color("69795e"))
			var enough: bool = branches >= recipe[1] and rocks >= recipe[2] and ropes >= recipe[3]
			if i == 5: enough = enough and weapons.has("Large stone sword")
			ui_button(Rect2(base + Vector2(570, y), Vector2(118, 39)), "Craft", "craft_" + str(i), enough)
		if message_time > 0: label_at(base + Vector2(30, 430), message, 16)
		ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "C / Esc  Close", "close")
	elif inventory:
		label_at(base + Vector2(30, 42), "BACKPACK - %d / 10 materials" % (branches + rocks + ropes), 25)
		for i in range(3):
			draw_texture_rect(resource_art[i * 3], Rect2(base + Vector2(30, 76 + i * 44), Vector2(33, 29)), false)
			label_at(base + Vector2(79, 99 + i * 44), ["Branches", "Rocks", "Ropes"][i] + " x " + str([branches, rocks, ropes][i]), 20)
			ui_button(Rect2(base + Vector2(555, 73 + i * 44), Vector2(130, 35)), "Drop 1", "drop_" + str(i))
		label_at(base + Vector2(30, 232), "Power %d   |   Fullness %d / 100   |   Stones %d   Medicine %d" % [power, fullness, magic_stones, medicine], 18)
		label_at(base + Vector2(30, 268), "WEAPONS (power is cumulative)", 17)
		if not equipment_art.is_empty():
			draw_texture_rect(equipment_art[6], Rect2(base + Vector2(472, 182), Vector2(26, 30)), false)
			draw_texture_rect(equipment_art[7], Rect2(base + Vector2(510, 181), Vector2(23, 31)), false)
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
		label_at(base + Vector2(30, 498), "Fullness gives warnings only in this version.", 16, Color("69795e"))
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
