extends Node2D
# 0.1.0: All visuals are drawn with simple shapes; no external art needed.
const WORLD := Vector2(2200, 1500)
const SPEED := 240.0
const CAPACITY := 10
var player := Vector2(360, 760)
var camera := Vector2.ZERO
var facing := Vector2.DOWN
var branches := 0
var rocks := 0
var ropes := 0
var crystals := 0
var sword := false
var quest := false
var won := false
var paused := false
var inventory := false
var dialog := ""
var message := "欢迎来到森林。靠近营地向导，按 E 交谈。"
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
	var mac_font := "/System/Library/Fonts/STHeiti Light.ttc"
	if FileAccess.file_exists(mac_font):
		var local_font := FontFile.new()
		local_font.data = FileAccess.get_file_as_bytes(mac_font)
		font = local_font
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Noto Sans CJK SC", "Microsoft YaHei", "Arial"])
		font = system_font
	build_world()
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
	for p in [Vector2(1380, 760), Vector2(1700, 1220), Vector2(1700, 300)]:
		add_item(p, "crystal")

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
	var dt := minf(delta, 0.04)
	if not paused and not inventory and dialog.is_empty() and not won:
		elapsed += dt
		message_time = maxf(0, message_time - dt)
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
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_R and won:
		get_tree().reload_current_scene()
		return
	if key == KEY_ESCAPE:
		if not dialog.is_empty(): dialog = ""
		elif inventory: inventory = false
		elif not won: paused = not paused
		queue_redraw()
		return
	if won or paused: return
	if not dialog.is_empty():
		if key == KEY_E or key == KEY_SPACE: dialog = ""
		return
	if key == KEY_B:
		inventory = not inventory
		return
	if inventory: return
	if key == KEY_E: interact()
	if key == KEY_C: craft()

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
		notify("走近 NPC、材料或出口，再按 E。")
		return
	match target.kind:
		"guide":
			quest = true
			dialog = "营地向导 · 林叔\n\n森林出口需要 3 枚蓝色晶石。\n先沿小路收集材料，按 C 制作石剑。\n配方：3 树枝 + 4 石头 + 3 草绳。\n\n晶石在东边小路、南边林地和北边古道。\n带上石剑和晶石，去东北方的拱门。"
		"scout":
			dialog = "巡林员 · 阿青\n\n沿东边的南北小路就能找到另外两枚晶石。\n材料背包只能装 10 件，石剑和晶石不占容量。\n拿多了某种材料？按 B 打开背包可用鼠标丢弃。\n\n这个初版可以安心探索，没有敌人和时间限制。"
		"gate":
			if sword and crystals == 3: won = true
			else: notify("出口尚未开启：需要一把石剑和 3 枚晶石。")
		"item":
			collect_item(int(target.index))

func collect_item(index: int) -> void:
	if items[index].taken: return
	var kind: String = items[index].kind
	if kind != "crystal" and branches + rocks + ropes >= CAPACITY:
		notify("材料背包已满。按 C 制作，或按 B 丢弃多余材料。")
		return
	items[index].taken = true
	match kind:
		"branch": branches += 1
		"rock": rocks += 1
		"rope": ropes += 1
		"crystal": crystals += 1
	notify("获得 " + item_name(kind))

func craft() -> void:
	if sword:
		notify("你已经装备石剑，可以继续寻找晶石。")
	elif branches >= 3 and rocks >= 4 and ropes >= 3:
		branches -= 3
		rocks -= 4
		ropes -= 3
		sword = true
		notify("石剑制作成功！现在去寻找 3 枚蓝色晶石。")
	else:
		notify("石剑需要 3 树枝、4 石头、3 草绳。当前 %d / %d / %d。" % [branches, rocks, ropes])

func item_name(kind: String) -> String:
	return {"branch": "树枝", "rock": "石头", "rope": "草绳", "crystal": "蓝色晶石"}.get(kind, kind)

func _input(event: InputEvent) -> void:
	if inventory and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var base := get_viewport_rect().size * 0.5 - Vector2(245, 195)
		for i in range(3):
			if Rect2(base + Vector2(350, 90 + i * 52), Vector2(100, 36)).has_point(event.position):
				# Drop back into the world, never destroy a needed resource.
				var kinds := ["branch", "rock", "rope"]
				var amounts := [branches, rocks, ropes]
				if amounts[i] > 0:
					if i == 0: branches -= 1
					if i == 1: rocks -= 1
					if i == 2: ropes -= 1
					add_item(player, kinds[i])

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
	draw_set_transform(-camera + p, 0, Vector2(1, 0.4))
	draw_circle(Vector2(0, 27), 21, Color(0, 0, 0, 0.2))
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
	label_at(Vector2(275, 675), "旅人营地", 20)
	label_at(Vector2(1580, 1360), "南边林地", 22)
	label_at(Vector2(1580, 195), "北边古道", 22)
	label_at(Vector2(940, 330), "静水湖", 20)
	for tree in trees:
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
	draw_rect(Rect2(gate - Vector2(30, 70), Vector2(60, 95)), Color(0.4, 0.8, 0.8, 0.35 if crystals == 3 else 0.08))
	label_at(gate + Vector2(-40, -106), "森林出口", 20)
	person(npc_home, Color("d7a454"), "林叔")
	person(npc_position, Color("b6a5cd"), "阿青")
	person(player, Color("7ac8c1"), "", true)
	var target := nearest_target()
	if not target.is_empty() and dialog.is_empty() and not inventory and not won:
		var text := "E  交谈"
		if target.kind == "gate": text = "E  开启出口"
		if target.kind == "item": text = "E  拾取" + item_name(items[int(target.index)].kind)
		label_at(player + Vector2(-40, -66), text, 18, Color("fff0b5"))
	draw_set_transform(Vector2.ZERO)
	# Screen-space HUD and a compact map.
	draw_rect(Rect2(0, 0, screen.x, 106), Color("172c2b"))
	label_at(Vector2(24, 32), "森林旅人", 25)
	label_at(Vector2(160, 31), "0.1.0 · 探索原型", 16, Color("a0b7a7"))
	label_at(Vector2(24, 63), "目标：制作石剑 → 找到 3 枚晶石 → 前往东北出口", 19)
	label_at(Vector2(24, 90), "树枝 %d   石头 %d   草绳 %d   |   材料 %d/10   |   晶石 %d/3   |   石剑：%s" % [branches, rocks, ropes, branches + rocks + ropes, crystals, "已装备" if sword else "未制作"], 17)
	var map_pos := Vector2(screen.x - 188, 122)
	draw_rect(Rect2(map_pos, Vector2(164, 112)), Color("1c3530"))
	var map_scale := Vector2(164, 112) / WORLD
	draw_line(map_pos + Vector2(100, 760) * map_scale, map_pos + Vector2(2030, 760) * map_scale, Color("877c59"), 3)
	draw_line(map_pos + Vector2(1700, 230) * map_scale, map_pos + Vector2(1700, 1310) * map_scale, Color("877c59"), 3)
	for item in items:
		if item.kind == "crystal" and not item.taken: draw_circle(map_pos + item.pos * map_scale, 3, Color("82d9df"))
	draw_circle(map_pos + gate * map_scale, 4, Color("e5c47c"))
	draw_circle(map_pos + player * map_scale, 4, Color.WHITE)
	label_at(map_pos + Vector2(0, 134), "白：你   蓝：晶石   黄：出口", 12)
	draw_rect(Rect2(0, screen.y - 46, screen.x, 46), Color("172c2b"))
	label_at(Vector2(24, screen.y - 17), "WASD / 方向键 移动     E 交互     B 背包     C 制作石剑     Esc 暂停", 17)
	if message_time > 0:
		draw_rect(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("233a32"))
		label_at(Vector2(34, screen.y - 72), message, 17)
	if inventory or paused or not dialog.is_empty() or won:
		draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.07, 0.08, 0.78))
		var base := screen * 0.5 - Vector2(245, 195)
		draw_rect(Rect2(base, Vector2(490, 390)), Color("203b36"))
		if inventory:
			label_at(base + Vector2(30, 46), "背包 · 材料 %d / 10" % (branches + rocks + ropes), 25)
			var names := ["树枝", "石头", "草绳"]
			var counts := [branches, rocks, ropes]
			for i in range(3):
				label_at(base + Vector2(30, 116 + i * 52), names[i] + " × " + str(counts[i]), 21)
				draw_rect(Rect2(base + Vector2(350, 90 + i * 52), Vector2(100, 36)), Color("496252"))
				label_at(base + Vector2(366, 115 + i * 52), "丢下 1", 17)
			label_at(base + Vector2(30, 277), "晶石 %d / 3  ·  石剑：%s" % [crystals, "已装备" if sword else "无"], 20)
			label_at(base + Vector2(30, 324), "石剑配方：3 树枝 + 4 石头 + 3 草绳", 18)
			label_at(base + Vector2(30, 362), "B / Esc 关闭，再按 C 制作", 17)
		elif won:
			label_at(base + Vector2(35, 85), "森林的出口，已为你开启。", 26)
			label_at(base + Vector2(35, 145), "你带着石剑与三枚晶石完成了探索！", 21)
			label_at(base + Vector2(35, 206), "初版通关 · 感谢试玩", 21)
			label_at(base + Vector2(35, 310), "按 R 重新开始，或关闭窗口退出", 18)
		elif paused:
			label_at(base + Vector2(35, 95), "已暂停", 30)
			label_at(base + Vector2(35, 165), "Esc 返回森林", 22)
			label_at(base + Vector2(35, 230), "当前版本暂不存档，关闭后重新开始。", 18)
		else:
			var lines := dialog.split("\n")
			for i in range(lines.size()): label_at(base + Vector2(25, 42 + i * 32), lines[i], 23 if i == 0 else 18)
			label_at(base + Vector2(25, 363), "E / 空格 / Esc 继续", 17, Color("d8c58f"))
