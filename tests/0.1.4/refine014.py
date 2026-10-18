from pathlib import Path
import shutil
p=Path('outputs/adventure game 0.1.4/main.gd'); dst=p.parent
origin=Path('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872')
for source,name in [('exec-9447566d-8b4f-4696-821c-ae094108c34d.png','traveler-directions.png'),('exec-a1ddeeb8-1c4f-457f-9b74-941cb476305a.png','environment.png'),('exec-21aed9c3-d0e3-4757-8b3c-d736255a408b.png','materials.png'),('exec-60102496-cb7e-43b0-aafa-f37892ae85c2.png','ponds.png'),('exec-8e604195-311d-437f-87c9-7fd879c6f43b.png','npcs.png')]:
 shutil.copyfile(origin/source,dst/'assets'/name)
s=p.read_text()
s=s.replace('var cabin := Rect2(240, 490, 220, 145)','var cabin := Rect2(240, 520, 220, 115)')
s=s.replace('var art: Array[Texture2D] = []','''var art: Array[Texture2D] = []
var traveler_art: Array[Texture2D] = []
var resource_art: Array[Texture2D] = []
var pond_art: Array[Texture2D] = []
var npc_art: Array[Texture2D] = []
var pools: Array[Rect2] = []
var pond_colliders: Array[PackedVector2Array] = []
var shrubs: Array[Vector2] = []
var show_collision := false''')
a=s.index('func load_art()');b=s.index('\tvar rng :=',a)
s=s[:a]+'''func load_grid(path: String, columns: int, rows: int) -> Array[Texture2D]:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(path))
	var textures: Array[Texture2D] = []
	for row in range(rows):
		for col in range(columns):
			var x := int(float(col) * sheet.get_width() / columns)
			var y := int(float(row) * sheet.get_height() / rows)
			var right := int(float(col + 1) * sheet.get_width() / columns)
			var bottom := int(float(row + 1) * sheet.get_height() / rows)
			var part := sheet.get_region(Rect2i(x, y, right - x, bottom - y))
			textures.append(ImageTexture.create_from_image(part.get_region(part.get_used_rect())))
	return textures

func load_art() -> void:
	art = load_grid("res://assets/environment.png", 3, 2)
	traveler_art = load_grid("res://assets/traveler-directions.png", 4, 2)
	resource_art = load_grid("res://assets/materials.png", 3, 3)
	pond_art = load_grid("res://assets/ponds.png", 1, 3)
	npc_art = load_grid("res://assets/npcs.png", 2, 2)
	meadow = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
''' +s[b:]
a=s.index('func painted_sprite(');b=s.index('func paper_panel(',a)
s=s[:a]+'''func sprite_rect(tex: Texture2D, foot: Vector2, height: float) -> Rect2:
	var width := height * tex.get_width() / tex.get_height()
	return Rect2(foot - Vector2(width * 0.5, height), Vector2(width, height))

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

''' +s[b:]
s=s.replace('\tobstacles = [pond, cabin]','''	trees.clear()
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
		pond_colliders.append(poly)''')
s=s.replace('\t\tif pond.grow(65).has_point(p) or cabin.grow(70).has_point(p):\n\t\t\tcontinue','''		var by_water := false
		for pool in pools:
			if pool.grow(80).has_point(p): by_water = true
		if by_water or cabin.grow(95).has_point(p): continue''')
s=s.replace('obstacles.append(Rect2(p - Vector2(20, 12), Vector2(40, 38)))','''obstacles.append(Rect2(p - Vector2(16, 13), Vector2(32, 21)))
		if i % 4 == 0:
			var shrub := p + Vector2(65, 24)
			shrubs.append(shrub)
			obstacles.append(Rect2(shrub - Vector2(19, 13), Vector2(38, 23)))''')
a=s.index('func walkable(');b=s.index('func _process(',a)
s=s[:a]+'''func walkable(p: Vector2) -> bool:
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

''' +s[b:]
s=s.replace('\t\t\tmoving = direction.length_squared() > 0\n\t\t\tmove_player(direction, dt)','\t\t\tvar previous := player\n\t\t\tmove_player(direction, dt)\n\t\t\tmoving = player.distance_to(previous) > 0.1')
s=s.replace('\t\t\tnpc_position = npc_scout + Vector2(sin(elapsed * 0.65) * 55, 0)','''			var scout_next := npc_scout + Vector2(sin(elapsed * 0.65) * 55, 0)
			if not feet_rect(scout_next).intersects(feet_rect(player)): npc_position = scout_next''')
s=s.replace('\tvar key: int = event.physical_keycode','\tvar key: int = event.physical_keycode\n\tif key == KEY_F3:\n\t\tshow_collision = not show_collision\n\t\treturn',1)
a=s.index('func person(');b=s.index('func _draw()',a)
s=s[:a]+'''func person(p: Vector2, _color: Color, title: String, is_player: bool = false) -> void:
	draw_ellipse_shadow(p)
	if is_player and not traveler_art.is_empty():
		var frame := direction_index(facing)
		if moving and int(elapsed * 7.0) % 2 == 1: frame += 4
		draw_sprite(traveler_art[frame], p, 67)
		draw_arc(p + Vector2(0, -2), 15, 0.05, PI - 0.05, 20, Color(0.98, 0.88, 0.6, 0.72), 1.5, true)
		if sword:
			var side := -1.0 if facing.x < 0 else 1.0
			draw_line(p + Vector2(side * 18, -6), p + Vector2(side * 24, -30), Color("d8e3da"), 3, true)
			draw_line(p + Vector2(side * 13, -10), p + Vector2(side * 23, -8), Color("c89d50"), 3, true)
	elif not npc_art.is_empty():
		var frame := 0 if title == "Rowan" else 1
		if player.y < p.y - 32 and player.distance_to(p) < 110: frame += 2
		draw_sprite(npc_art[frame], p, 69)
		label_at(p + Vector2(-26, -81), title, 16, Color("fff2cc"))

func draw_ellipse_shadow(p: Vector2) -> void:
	# Every direction uses the same ground anchor; art never has a negative-width rect.
	var progress := day_fraction()
	var cast := Vector2(lerpf(12, -12, progress), 4)
	draw_set_transform(-camera + p + cast * 0.4, 0, Vector2(1.0 + absf(progress - 0.5) * 0.5, 0.32))
	draw_circle(Vector2.ZERO, 15, Color(0.025, 0.055, 0.05, 0.23))
	draw_set_transform(-camera)

func draw_collision_overlay() -> void:
	for rect in obstacles: draw_rect(rect, Color(1, 0.47, 0.32, 0.85), false, 2)
	for polygon in pond_colliders:
		var outline := polygon.duplicate()
		outline.append(polygon[0])
		draw_polyline(outline, Color(0.35, 0.82, 1, 0.9), 2, true)
	for npc in [npc_home, npc_position]: draw_rect(feet_rect(npc), Color("efb850"), false, 2)
	draw_rect(feet_rect(player), Color("b4ffbd"), false, 2)
	draw_circle(player, 3, Color.WHITE)

''' +s[b:]
a=s.index('\t# Lake keeps');b=s.index('\tlabel_at(Vector2(1580',a)
s=s[:a]+'''	for i in range(pools.size()):
		if not pond_art.is_empty(): draw_texture_rect(pond_art[i], pools[i], false)
		var center := pools[i].get_center()
		for wave in range(3):
			var start := center + Vector2(-35 + wave * 27 + sin(elapsed + wave) * 3, -12 + wave * 14)
			draw_line(start, start + Vector2(17, -1), Color(0.78, 0.94, 0.87, 0.21), 1.5, true)
''' +s[b:]
a=s.index('\tfor item in items:',s.index('func _draw()'));b=s.index('\t# Depth-sort',a)
s=s[:a]+'''	for i in range(items.size()):
		var item: Dictionary = items[i]
		if item.taken: continue
		var p: Vector2 = item.pos
		var row := 0 if item.kind == "branch" else (1 if item.kind == "rock" else 2)
		if not resource_art.is_empty():
			var tex := resource_art[row * 3 + i % 3]
			var size := Vector2(34, 27) if row == 0 else Vector2(29, 24)
			draw_texture_rect(tex, Rect2(p - size * 0.5, size), false)
''' +s[b:]
s=s.replace('for tree in trees: scenery.append({"p": tree, "kind": "tree"})','for tree in trees: scenery.append({"p": tree, "kind": "tree"})\n\tfor shrub in shrubs: scenery.append({"p": shrub, "kind": "shrub"})')
s=s.replace('painted_sprite(0, p + Vector2(0, 23), 144 + int(p.x) % 27, int(p.x) % 2 == 0, Color(1, 1, 1, 0.48 if faded else 1.0))','painted_sprite((int(p.x) + int(p.y)) % 3, p + Vector2(0, 5), 117 + int(p.x) % 24, false, Color(1, 1, 1, 0.42 if faded else 1.0))')
s=s.replace('"cabin": painted_sprite(1, p, 233)','"shrub": painted_sprite(3, p + Vector2(0, 9), 57)\n\t\t\t"cabin": painted_sprite(4, p, 222)')
s=s.replace('"gate": painted_sprite(5, p, 155)','"gate": painted_sprite(5, p, 132)')
s=s.replace('\tdraw_set_transform(Vector2.ZERO)\n\tdraw_survival_ui(screen)','\tif show_collision: draw_collision_overlay()\n\tdraw_set_transform(Vector2.ZERO)\n\tdraw_survival_ui(screen)\n\tif show_collision:\n\t\tpaper_panel(Rect2(270, 125, 570, 31), Color("203d40"), 6)\n\t\tlabel_at(Vector2(283, 147), "F3  COLLISIONS: green = feet / coral = solid / blue = water", 15)')
s=s.replace('WASD / Arrows: Move    E: Interact    B: Bag    C: Craft    Esc: Pause','WASD / Arrows: Move    E: Interact    B: Bag    C: Craft    Esc: Pause    F3: Hitboxes')
p.write_text(s)
