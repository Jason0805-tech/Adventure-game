extends "res://../../tests/0.1.5.3/capture_canvas.gd"
# 0.1.5.3: AI-painted 2D traveler with shared right-hand grip and articulated gait.
const WORLD := Vector2(2200, 1500)
const SPEED := 72.0
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
var health := 100.0
var hunger_elapsed := 0.0
@export var resource_seed: int = 0
var props: Array[Dictionary] = []
var harvest_art: Array[Texture2D] = []
var prop_art: Array[Texture2D] = []
var status_art: Array[Texture2D] = []
var avatar_unarmed: Texture2D
var avatar_armed: Texture2D
var held_weapon_art: Array[Texture2D] = []
const FACING_ANGLES := [0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330]
const AVATAR_CELL := Vector2(96, 160)
const AVATAR_ANCHOR := Vector2(48, 134)
const AVATAR_SCALE := 0.80
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
var walk_distance := 0.0
const WALK_STRIDE := 60.48 # Side-view support-foot travel (1.8) * pose scale (42) * sprite scale (0.8)


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

func auto_grid(path: String, columns: int, rows: int) -> Array[Texture2D]:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(path))
	sheet.convert(Image.FORMAT_RGBA8)
	var data := sheet.get_data()
	var width := sheet.get_width()
	var height := sheet.get_height()
	var ys: Array = [0.0]
	for row in range(1, rows):
		var expected := int(float(row) * height / rows)
		var radius := int(float(height) / rows * 0.40)
		var best := expected
		var score := INF
		for y in range(maxi(1, expected - radius), mini(height - 1, expected + radius)):
			var occupied := 0
			for x in range(0, width, 2):
				if data[(y * width + x) * 4 + 3] > 100: occupied += 1
			var cost := occupied + absf(y - expected) * 0.001
			if cost < score: score = cost; best = y
		ys.append(float(best) / height)
	ys.append(1.0)
	var xs: Array = []
	for row in range(rows):
		var cuts: Array = [0]
		for col in range(1, columns):
			var expected := int(float(col) * width / columns)
			var radius := int(float(width) / columns * 0.40)
			var best := expected
			var score := INF
			for x in range(maxi(1, expected - radius), mini(width - 1, expected + radius)):
				var occupied := 0
				for y in range(int(ys[row] * height), int(ys[row + 1] * height), 2):
					if data[(y * width + x) * 4 + 3] > 100: occupied += 1
				var cost := occupied + absf(x - expected) * 0.001
				if cost < score: score = cost; best = x
			cuts.append(best)
		cuts.append(width)
		xs.append(cuts)
	return load_grid(path, columns, rows, ys, xs)

func load_texture(path: String) -> Texture2D:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))

func load_art() -> void:
	art = load_grid("res://assets/environment.png", 3, 2, [0.0, 552.0/1024, 1.0], [[0,520,1024,1536],[0,499,1024,1536]])
	resource_art = load_grid("res://assets/materials.png", 3, 3, [0.0, 0.36, 0.67, 1.0])
	pond_art = load_grid("res://assets/ponds.png", 3, 1, [], [[0,607,1208,1774]])
	variant_art = load_grid("res://assets/tree-variants.png", 3, 2, [0.0, 624.0/1024, 1.0], [[0,512,1024,1536],[0,516,1024,1536]])
	equipment_art = load_grid("res://assets/equipment.png", 4, 2)
	blend_art = load_grid("res://assets/ground-blends.png", 3, 2, [], [[0,512,1024,1536],[0,522,1024,1536]])
	npc_art = load_grid("res://assets/npcs.png", 2, 2)
	harvest_art = auto_grid("res://assets/harvest-nodes.png", 3, 6)
	prop_art = auto_grid("res://assets/cabin-props.png", 3, 2)
	status_art = auto_grid("res://assets/status-icons.png", 2, 1)
	avatar_unarmed = load_texture("res://assets/traveler-unarmed-directions.png")
	avatar_armed = load_texture("res://assets/traveler-armed-directions.png")
	held_weapon_art.clear()
	for index in range(6): held_weapon_art.append(load_texture("res://assets/held-weapon-%d.png" % index))
	for texture in npc_art + art + variant_art + harvest_art + prop_art:
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
		record_draw_texture_rect(blend_art[index], Rect2(center - size * 0.5, size), false, Color(1, 1, 1, opacity))

func varied_tree(p: Vector2, faded: bool) -> void:
	var seed_value := absi(int(p.x * 17 + p.y * 31))
	var variant: int = tree_styles.get(p, seed_value % 6)
	var tex: Texture2D = art[variant] if variant < 3 else variant_art[variant - 3]
	var height := 148.0 + seed_value % 39
	var warmth := float(seed_value % 11) / 180.0
	var tint := Color(1.0 - warmth * 0.35, 1.0 - warmth * 0.15, 1.0 - warmth, 0.42 if faded else 1.0)
	# Mirror around the shared ground anchor, never via a negative texture rectangle.
	record_draw_set_transform(-camera + p, 0, Vector2(-1 if seed_value % 2 else 1, 1))
	draw_sprite(tex, Vector2(0, 5), height, tint)
	record_draw_set_transform(-camera)

func sprite_rect(tex: Texture2D, foot: Vector2, height: float) -> Rect2:
	var scale := height / tex.get_height()
	var width := tex.get_width() * scale
	var pivot: Vector2 = foot_anchors.get(tex, Vector2(tex.get_width() * 0.5, tex.get_height()))
	return Rect2(foot - pivot * scale, Vector2(width, height))

func draw_sprite(tex: Texture2D, foot: Vector2, height: float, tint: Color = Color.WHITE) -> void:
	record_draw_texture_rect(tex, sprite_rect(tex, foot, height), false, tint)

func painted_sprite(index: int, foot: Vector2, height: float, _flip: bool = false, tint: Color = Color.WHITE) -> void:
	if not art.is_empty(): draw_sprite(art[index], foot, height, tint)

func direction_index(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 1 if direction.x < 0 else 2
	return 3 if direction.y < 0 else 0

func feet_rect(p: Vector2) -> Rect2:
	# Painted boots are wider than the old thin-legged model.
	return Rect2(p - Vector2(15, 10), Vector2(30, 18))

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
	record_draw_style_box(style, rect)


func _ready() -> void:
	font = ThemeDB.fallback_font
	load_art()
	build_world()
	print("GAME_READY 0.1.5.3")
	queue_redraw()

func build_world() -> void:
	tree_styles.clear()
	trees.clear()
	items.clear()
	shrubs.clear()
	pond_colliders.clear()
	pools = [pond, Rect2(550, 1080, 220, 150), Rect2(1380, 380, 210, 135)]
	props = [{"p": Vector2(512, 649), "sprite": 1, "height": 49.0, "rect": Rect2(482,632,62,23)}, {"p": Vector2(229,630), "sprite": 3, "height": 46.0, "rect": Rect2(212,614,33,20)}, {"p": Vector2(265,666), "sprite": 4, "height": 34.0, "rect": Rect2(249,654,34,18)}]
	obstacles = [cabin, Rect2(gate + Vector2(-57, -19), Vector2(29, 49)), Rect2(gate + Vector2(29, -19), Vector2(29, 49))]
	for prop in props: obstacles.append(prop.rect)
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
	var supplies := RandomNumberGenerator.new()
	if resource_seed == 0: supplies.randomize()
	else: supplies.seed = resource_seed
	spawn_resources(supplies, "branch", 22)
	spawn_resources(supplies, "rock", 18)
	spawn_resources(supplies, "rope", 18)
	spawn_resources(supplies, "berry", 9)

func tree_distance(p: Vector2) -> float:
	var distance := 99999.0
	for tree in trees: distance = minf(distance, p.distance_to(tree))
	return distance

func forest_density(p: Vector2) -> int:
	var density := 0
	for tree in trees:
		if tree.distance_to(p) < 190: density += 1
	return density

func near_path(p: Vector2) -> bool:
	return absf(p.y - 760) < 78 or absf(p.x - 1700) < 78

func spawn_resources(rng: RandomNumberGenerator, kind: String, count: int) -> void:
	var placed := 0
	for attempt in range(6000):
		if placed >= count: break
		var p: Vector2
		if kind == "branch" or kind == "berry":
			var tree: Vector2 = trees[rng.randi_range(0, trees.size() - 1)]
			p = tree + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(47, 116)
		elif kind == "rock":
			var regions := [Vector2(820,610),Vector2(1440,620),Vector2(660,1040),Vector2(1900,1150)]
			p = regions[rng.randi_range(0,3)] + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(45,215)
		else:
			p = Vector2(rng.randf_range(90, 2110),rng.randf_range(130,1390))
			if tree_distance(p) < 92 or forest_density(p) >= 3: continue
		# Favor an accessible first-day region without forcing pickups onto a road.
		if placed < 6 and p.distance_to(Vector2(550,800)) > 540: continue
		if p.distance_to(Vector2(360,760)) < 75: continue
		if near_path(p) and rng.randf() < 0.88: continue
		if not walkable(p) or not walkable(p + Vector2(0,30)): continue
		if p.distance_to(npc_home) < 75 or p.distance_to(npc_scout) < 120 or cabin.grow(28).has_point(p): continue
		var crowded := false
		for item in items:
			if item.pos.distance_to(p) < 68: crowded = true; break
		if crowded: continue
		add_item(p,kind)
		items[-1]["variant"] = rng.randi_range(0,2)
		items[-1]["mirror"] = rng.randf() < 0.5
		placed += 1
	if placed < count: push_warning("Resource placement below target: " + kind)

func resource_rect(item: Dictionary) -> Rect2:
	return Rect2(item.pos - Vector2(13,10),Vector2(26,15))


func add_item(p: Vector2, kind: String) -> void:
	items.append({"pos": p, "kind": kind, "taken": false, "variant": items.size() % 3, "mirror": false})

func walkable(p: Vector2) -> bool:
	if p.x < 32 or p.y < 40 or p.x > WORLD.x - 32 or p.y > WORLD.y - 32:
		return false
	var feet := feet_rect(p)
	for rect in obstacles:
		if feet.intersects(rect): return false
	for item in items:
		if not item.taken and not item.get("dropped",false) and item.kind != "rope" and feet.intersects(resource_rect(item)): return false
	for npc in [npc_home, npc_position]:
		if feet.intersects(feet_rect(npc)): return false
	var polygon := rect_polygon(feet)
	for collider in pond_colliders:
		if not Geometry2D.intersect_polygons(polygon, collider).is_empty(): return false
	return true

func move_player(direction: Vector2, delta: float) -> void:
	if direction.length() > 0:
		var target_angle := atan2(direction.x,direction.y)
		var current_angle := atan2(facing.x,facing.y)
		var angle := lerp_angle(current_angle,target_angle,1.0-exp(-maxf(0,delta)*18.0))
		facing = Vector2(sin(angle),cos(angle))
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

func _process(delta: float) -> void:
	moving = false
	var dt := minf(delta, 0.05)
	if not paused:
		elapsed += dt
		message_time = maxf(0, message_time - dt)
		if phase == "day":
			advance_vitals(delta)
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
	if key == KEY_H:
		use_medicine()
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

func target_line_clear(target_position:Vector2) -> bool:
	var distance := player.distance_to(target_position)
	var samples := maxi(1,int(distance / 9))
	for i in range(1,samples):
		var sample := player.lerp(target_position,float(i)/samples)
		if sample.distance_to(target_position) < 18: continue
		for obstacle in obstacles:
			if obstacle.has_point(sample): return false
		for water in pond_colliders:
			if Geometry2D.is_point_in_polygon(sample,water): return false
	return true

func nearest_target() -> Dictionary:
	var best := 85.0
	var target: Dictionary = {}
	var candidates: Array[Dictionary] = [{"pos": npc_home, "kind": "guide"}, {"pos": npc_position, "kind": "scout"}, {"pos": gate, "kind": "gate"}]
	for i in range(items.size()):
		if not items[i].taken:
			candidates.append({"pos": items[i].pos, "kind": "item", "index": i})
	for candidate in candidates:
		var distance := player.distance_to(candidate.pos)
		if distance < best and target_line_clear(candidate.pos):
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
			dialog = "Rowan - Camp guide\n\nSurvive three nights to escape this forest.\nGather shrubs, rock outcrops and fiber grass.\nPress C to craft. Berry shrubs restore fullness.\nNight arrives automatically after 90 seconds.\n\nThe threats need 3, 6 and 9 power.\nA magic stone or medicine can save you once."
		"scout":
			dialog = "Ash - Forest scout\n\nAt night: explore, rest, or look for food.\nExplore gives +2 power and a magic stone.\nRest gives +1 power. Food gives +1 and medicine.\nEvery night costs fullness; check the action cards.\n\nGather berry shrubs to restore fullness.
H uses medicine to heal; starving drains health.\nThe timer runs in menus. Esc pauses the game."
		"gate":
			notify("The forest is unsafe. Survive all three nights to escape.")
		"item":
			collect_item(int(target.index))

func collect_item(index: int) -> void:
	if index < 0 or index >= items.size(): return
	if items[index].taken: return
	var kind: String = items[index].kind
	if phase != "day": return
	if kind != "berry" and branches + rocks + ropes >= CAPACITY:
		notify("Bag full. Press C to craft, or B to drop extra supplies.")
		print("PICKUP_BLOCKED: bag full; items=", branches + rocks + ropes)
		return
	print("PICKUP: ", kind, " at index ", index)
	items[index].taken = true
	match kind:
		"branch": branches += 1
		"rock": rocks += 1
		"rope": ropes += 1
		"berry": fullness = mini(100, fullness + 22)
	notify("Ate forest berries. Fullness +22." if kind == "berry" else ("Gathered: " + item_name(kind)))

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

func take_damage(amount: float) -> void:
	health = clampf(health - maxf(0, amount), 0, 100)
	if health <= 0 and not won:
		lost = true
		phase = "lost"
		result_text = "Your health ran out. Gather food and prepare better equipment."

func advance_vitals(dt: float) -> void:
	if paused or phase != "day" or won or lost: return
	var elapsed_time := maxf(0,dt)
	var until_starving := maxf(0,(fullness-hunger_elapsed)/0.06)
	hunger_elapsed += elapsed_time * 0.06
	var hunger_cost := int(hunger_elapsed)
	if hunger_cost > 0:
		fullness = maxi(0,fullness-hunger_cost)
		hunger_elapsed -= hunger_cost
	var starving_time := maxf(0,elapsed_time-until_starving)
	if starving_time > 0: take_damage(starving_time*1.5)

func use_medicine() -> void:
	if phase != "day" or paused or health >= 100 or medicine <= 0: return
	medicine -= 1
	health = minf(100, health + 40)
	notify("Used medicine. Health +40.")

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
			health = minf(100,health+10)
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
			result_text = "A magic stone kept the danger away."
		else:
			var damage := 25.0 + (threat - power) * 10.0
			if medicine > 0:
				medicine -= 1
				health = minf(100, maxf(1, health - damage) + 40)
				result_text = "Medicine treated your wounds. One dose was consumed."
			else:
				take_damage(damage)
				result_text = "You were injured in the dark. Health -%d." % int(damage)
				if lost: return

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
	return {"branch": "Branches", "rock": "Rocks", "rope": "Fibers", "berry": "Berries", "crystal": "Blue crystal"}.get(kind, kind)

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
	if id == "heal": use_medicine(); return
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
	record_draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func avatar_direction(direction: Vector2) -> int:
	var heading := fposmod(rad_to_deg(atan2(direction.x,direction.y)),360.0)
	var best := 0
	var distance := INF
	for index in range(FACING_ANGLES.size()):
		var delta := absf(wrapf(heading-float(FACING_ANGLES[index]),-180,180))
		if delta < distance: distance=delta; best=index
	return best

func avatar_frame() -> int:
	return int(walk_distance / WALK_STRIDE * 8.0) % 8 if moving else 8

func equipped_weapon_index() -> int:
	if weapons.is_empty(): return -1
	for index in range(RECIPES.size()):
		if RECIPES[index][0] == weapons[-1]: return index
	return -1

func draw_traveler(p: Vector2, size_scale:float = 1.0) -> void:
	var direction := avatar_direction(facing)
	var frame := avatar_frame()
	var equipped := equipped_weapon_index()
	var texture := avatar_armed if equipped >= 0 else avatar_unarmed
	var source := Rect2(Vector2(direction * AVATAR_CELL.x,frame * AVATAR_CELL.y),AVATAR_CELL)
	var rect := Rect2(p - AVATAR_ANCHOR * AVATAR_SCALE * size_scale,AVATAR_CELL * AVATAR_SCALE * size_scale)
	record_draw_texture_rect_region(texture,rect,source)
	# The painted body and articulated palm occlude the hidden tool pixels.
	# Every tool uses the same anatomical right-hand anchor in every frame.
	if equipped >= 0: record_draw_texture_rect_region(held_weapon_art[equipped],rect,source)

func person(p: Vector2, _color: Color, title: String, is_player: bool = false) -> void:
	draw_ellipse_shadow(p)
	if is_player:
		draw_traveler(p)
	elif not npc_art.is_empty():
		var frame := 0 if title == "Rowan" else 1
		if player.y < p.y - 32 and player.distance_to(p) < 110: frame += 2
		draw_sprite(npc_art[frame],p,76)
		label_at(p + Vector2(-26,-81),title,16,Color("304c3c"))

func scenery_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for tree in trees: entries.append({"p":tree,"kind":"tree"})
	for shrub in shrubs: entries.append({"p":shrub,"kind":"shrub"})
	for index in range(items.size()): entries.append({"p":items[index].pos,"kind":"resource","index":index})
	for index in range(props.size()): entries.append({"p":props[index].p,"kind":"prop","index":index})
	entries.append({"p":Vector2(350,635),"kind":"cabin"})
	entries.append({"p":gate+Vector2(0,30),"kind":"gate"})
	entries.append({"p":npc_home,"kind":"Rowan"})
	entries.append({"p":npc_position,"kind":"Ash"})
	entries.append({"p":player,"kind":"player"})
	entries.sort_custom(func(a,b): return a.p.y < b.p.y)
	return entries

func draw_resource_node(index: int) -> void:
	var item: Dictionary = items[index]
	var p: Vector2 = item.pos
	if item.get("dropped",false):
		if item.taken: return
		var row := 0 if item.kind == "branch" else (1 if item.kind == "rock" else 2)
		record_draw_texture_rect(resource_art[row*3+int(item.variant)],Rect2(p-Vector2(14,11),Vector2(28,22)),false)
		return
	var row := 0 if item.kind in ["branch","berry"] else (1 if item.kind == "rock" else 2)
	var height := 38.0 if row != 1 else 30.0
	if item.taken: height *= 0.48
	var texture := harvest_art[row*3+int(item.variant)+(9 if item.taken else 0)]
	record_draw_set_transform(p-camera,0,Vector2(-1 if item.mirror else 1,1))
	draw_sprite(texture,Vector2(0,4),height,Color(0.91,0.94,0.86))
	record_draw_set_transform(-camera)

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
	record_draw_colored_polygon(outline, Color(0.08, 0.17, 0.16, 0.30 if daylight else 0.17))
	ground_patch(3, p + cast * 0.4, Vector2(49, 20), 0.35)
	var contact := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		contact.append(p + Vector2(cos(angle) * 13, sin(angle) * 4.5))
	record_draw_colored_polygon(contact, Color(0.055, 0.12, 0.11, 0.26))

func draw_collision_overlay() -> void:
	for rect in obstacles: record_draw_rect(rect, Color(1, 0.47, 0.32, 0.85), false, 2)
	for polygon in pond_colliders:
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		record_draw_polyline(outline, Color(0.35, 0.82, 1, 0.9), 2, true)
	for item in items:
		if not item.taken and not item.get("dropped",false) and item.kind != "rope": record_draw_rect(resource_rect(item),Color("d296c2"),false,1.0)
	for npc in [npc_home, npc_position]: record_draw_rect(feet_rect(npc), Color("efb850"), false, 2)
	record_draw_rect(feet_rect(player), Color("b4ffbd"), false, 2)
	record_draw_circle(player, 3, Color.WHITE)

func _draw() -> void:
	if font == null: return
	var screen := get_viewport_rect().size
	record_draw_set_transform(-camera)
	if meadow != null:
		record_draw_texture_rect(meadow, Rect2(Vector2.ZERO, WORLD), false)
	else:
		record_draw_rect(Rect2(Vector2.ZERO, WORLD), Color("71927b"))
	for detail in ground_details:
		ground_patch(detail.variant, detail.p, detail.size, 0.36)
	for tree in trees:
		ground_patch(0 if int(tree.x) % 2 else 1, tree + Vector2(0, 3), Vector2(94, 39), 0.58)
	ground_patch(2, Vector2(350, 634), Vector2(251, 65), 0.68)
	ground_patch(4, Vector2(354, 683), Vector2(113, 65), 0.46)
	for i in range(pools.size()):
		ground_patch(0, pools[i].get_center(), pools[i].size + Vector2(19, 17), 0.25)
		if not pond_art.is_empty(): record_draw_texture_rect(pond_art[i], pools[i], false)
		var center := pools[i].get_center()
		for wave in range(3):
			var start := center + Vector2(-35 + wave * 27 + sin(elapsed + wave) * 3, -12 + wave * 14)
			record_draw_line(start, start + Vector2(17, -1), Color(0.78, 0.94, 0.87, 0.21), 1.5, true)
	label_at(Vector2(1580, 1360), "SOUTHERN WOODS", 19, Color("304c3c"))
	label_at(Vector2(1580, 195), "NORTHERN TRAIL", 19, Color("304c3c"))
	label_at(Vector2(940, 325), "STILLWATER LAKE", 18, Color("304c3c"))
	for item in items:
		if not item.get("dropped",false): ground_patch(1,item.pos+Vector2(0,2),Vector2(51,19),0.22)
	var scenery := scenery_entries()
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
			"resource": draw_resource_node(int(entry.index))
			"prop":
				var prop: Dictionary = props[int(entry.index)]
				draw_sprite(prop_art[int(prop.sprite)],p,float(prop.height))
			"cabin": draw_sprite(prop_art[0],p,222)
			"gate": painted_sprite(5, p, 132)
			"Rowan": person(p, Color.WHITE, "Rowan")
			"Ash": person(p, Color.WHITE, "Ash")
			"player": person(p, Color.WHITE, "", true)
	label_at(Vector2(254, 665), "TRAVELERS CAMP", 18, Color("304c3c"))
	var target := nearest_target()
	if not target.is_empty() and dialog.is_empty() and not inventory and not crafting and phase == "day":
		var text := "E  Talk"
		if target.kind == "gate": text = "E  Open gate"
		if target.kind == "item": text = "E  " + ("Eat berries" if items[int(target.index)].kind == "berry" else "Gather " + item_name(items[int(target.index)].kind))
		label_at(player + Vector2(-40, -91), text, 18, Color("fff0b5"))
	if show_collision: draw_collision_overlay()
	record_draw_set_transform(Vector2.ZERO)
	draw_survival_ui(screen)
	if show_collision:
		paper_panel(Rect2(270, 155, 570, 31), Color("e9dcb6"), 6)
		label_at(Vector2(283, 177), "F3  COLLISIONS: green = feet / coral = solid / blue = water", 15)

func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
	paper_panel(rect, Color("426d67") if enabled else Color("304743"), 8)
	label_at(rect.position + Vector2(15, rect.size.y * 0.5 + 6), text, 17, Color("f2edda") if enabled else Color("8e9d93"))
	if enabled: buttons.append({"rect": rect, "id": id})

func painted_status(origin: Vector2, title: String, value: float, icon: int, color: Color) -> void:
	record_draw_texture_rect(status_art[icon],Rect2(origin + Vector2(0,5),Vector2(29,29)),false)
	label_at(origin + Vector2(39,17),title,15,Color("53634d"))
	label_at(origin + Vector2(222,17),"%d / 100" % int(ceil(clampf(value,0,100))),15,Color("53634d"))
	var bar := Rect2(origin + Vector2(39,23),Vector2(257,14))
	paper_panel(bar.grow(2),Color("8e9877"),4)
	var width := bar.size.x * clampf(value / 100.0,0,1)
	if width > 0:
		var outline := PackedVector2Array([bar.position,bar.position+Vector2(width,1),bar.position+Vector2(width,12),bar.position+Vector2(width*0.67,14),bar.position+Vector2(width*0.32,12),bar.position+Vector2(0,14)])
		record_draw_colored_polygon(outline,color)
		for i in range(7):
			var x := (i + 0.5) * width / 7.0
			record_draw_line(bar.position+Vector2(x-4,4+i%2),bar.position+Vector2(minf(width,x+6),5+i%2),Color(1,0.94,0.73,0.10),2,true)

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
		record_draw_rect(Rect2(Vector2.ZERO, screen), Color(0.96, 0.67, 0.35, morning * 0.07 + dusk * 0.13))
		record_draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.09, 0.23, dusk * 0.35))
	if darkness > 0:
		record_draw_rect(Rect2(Vector2.ZERO, screen), Color(0.025, 0.045, 0.13, darkness))
		# Lantern glow around the player and eyes watching from the woods.
		for i in range(5, 0, -1):
			record_draw_circle(player - camera, 22 + i * 17, Color(1.0, 0.72, 0.28, 0.025))
		if phase == "encounter":
			for x in [170, 290, 820, 945]:
				record_draw_circle(Vector2(x, 240 + (x % 3) * 60), 3, Color("d99562"))
				record_draw_circle(Vector2(x + 12, 240 + (x % 3) * 60), 3, Color("d99562"))
	paper_panel(Rect2(12,8,screen.x-24,135),Color("e9dcb6"))
	label_at(Vector2(24,32),"FOREST WANDERER",25)
	label_at(Vector2(335,31),"0.1.5.3  /  THREE NIGHTS",16,Color("657259"))
	label_at(Vector2(screen.x-265,32),("NIGHT IN "+clock_text()) if phase=="day" else ("NIGHT "+str(night)),22,Color("875c31"))
	painted_status(Vector2(24,43),"Health",health,0,Color("b7674c"))
	painted_status(Vector2(354,43),"Fullness",float(fullness),1,Color("bc984e"))
	label_at(Vector2(696,66),"Survived %d / 3   |   %s %d" % [survived,"Day" if phase=="day" else "Night",night],16)
	label_at(Vector2(696,92),"Threat %d   |   Power %d" % [night*3,power],16)
	label_at(Vector2(24,125),"Branches %d   Rocks %d   Fibers %d   |   Bag %d/10   |   Magic stones %d   Medicine %d" % [branches,rocks,ropes,branches+rocks+ropes,magic_stones,medicine],17)
	var map_pos := Vector2(screen.x - 180, 169)
	paper_panel(Rect2(map_pos - Vector2(8, 8), Vector2(172, 124)), Color("e6d8b3"))
	var map_scale := Vector2(156, 108) / WORLD
	record_draw_line(map_pos + Vector2(100, 760) * map_scale, map_pos + Vector2(2030, 760) * map_scale, Color("877c59"), 3)
	record_draw_line(map_pos + Vector2(1700, 230) * map_scale, map_pos + Vector2(1700, 1310) * map_scale, Color("877c59"), 3)
	record_draw_circle(map_pos + npc_home * map_scale, 4, Color("e5c47c"))
	record_draw_circle(map_pos + player * map_scale, 4, Color("28566a"))
	label_at(map_pos + Vector2(0, 129), "Blue: you / Gold: camp", 12)
	paper_panel(Rect2(12, screen.y - 45, screen.x - 24, 38), Color("e9dcb6"), 8)
	label_at(Vector2(24, screen.y - 17), "WASD / Arrows: Move    E: Gather / Talk    B: Bag    C: Craft    H: Heal    Esc: Pause    F3: Hitboxes", 17)
	var modal := inventory or crafting or paused or not dialog.is_empty() or phase != "day"
	if not modal:
		var time_name := "MORNING"
		if day_fraction() >= 0.35: time_name = "MIDDAY"
		if day_fraction() >= 0.7: time_name = "SUNSET - NIGHT APPROACHES"
		label_at(Vector2(24, 172), time_name, 16)
		label_at(Vector2(24, 199), "Night in " + clock_text(), 21)
		# A small sky strip shows the sun crossing from dawn to dusk.
		var sky := Color("819d9c").lerp(Color("c88861"), smoothstep(0.55, 1.0, day_fraction()))
		record_draw_rect(Rect2(24, 216, 225, 32), sky)
		record_draw_circle(Vector2(37 + day_fraction() * 198, 240 - sin(day_fraction() * PI) * 15), 7, Color("fff0b4"))
	if message_time > 0 and not modal:
		paper_panel(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("e6d8b3"), 8)
		label_at(Vector2(34, screen.y - 72), message, 17)
	if not modal: return
	record_draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.06, 0.07, 0.38))
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
			var cost := "%d branches / %d rocks / %d fibers" % [recipe[1], recipe[2], recipe[3]]
			if i == 5: cost = "Large stone sword + 1 rock (4 -> 5 power)"
			record_draw_texture_rect(equipment_art[i], Rect2(base + Vector2(29, y + 1), Vector2(33, 39)), false)
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
			record_draw_texture_rect(resource_art[i * 3], Rect2(base + Vector2(30, 76 + i * 44), Vector2(33, 29)), false)
			label_at(base + Vector2(79, 99 + i * 44), ["Branches", "Rocks", "Fibers"][i] + " x " + str([branches, rocks, ropes][i]), 20)
			ui_button(Rect2(base + Vector2(555, 73 + i * 44), Vector2(130, 35)), "Drop 1", "drop_" + str(i))
		label_at(base + Vector2(30, 232), "Health %d/100 | Fullness %d/100 | Stones %d | Medicine %d" % [int(ceil(health)), fullness, magic_stones, medicine], 18)
		label_at(base + Vector2(30, 268), "WEAPONS (power is cumulative)", 17)
		if not equipment_art.is_empty():
			record_draw_texture_rect(equipment_art[6], Rect2(base + Vector2(472, 182), Vector2(26, 30)), false)
			record_draw_texture_rect(equipment_art[7], Rect2(base + Vector2(510, 181), Vector2(23, 31)), false)
		var counts := {}
		for weapon in weapons: counts[weapon] = counts.get(weapon, 0) + 1
		var row := 0
		for weapon in counts:
			label_at(base + Vector2(30 + (row % 2) * 340, 302 + (row / 2) * 30), weapon + " x " + str(counts[weapon]), 16)
			row += 1
		if weapons.is_empty(): label_at(base + Vector2(30, 302), "None. Press C after closing to craft.", 17)
		label_at(base + Vector2(30, 423), food_check(), 17)
		ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "B / Esc  Close", "close")
		ui_button(Rect2(base + Vector2(464, 463), Vector2(220,42)), "H  Use medicine", "heal",medicine > 0 and health < 100)
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
		label_at(base + Vector2(45, 294), "+1 power, +10 health. Total fullness cost: 35.", 18)
		ui_button(Rect2(base + Vector2(30, 322), Vector2(660, 52)), "3  LOOK FOR FOOD", "action_2")
		label_at(base + Vector2(45, 399), "+1 power, +1 medicine. Berries offset the nightly 30 cost.", 18)
		label_at(base + Vector2(30, 468), "Low power: a stone protects you; medicine treats injuries.", 17)
		label_at(base + Vector2(30, 498), "Low power can injure you. Starving drains health in daylight.", 16, Color("69795e"))
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
