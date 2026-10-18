from pathlib import Path
p=Path(__file__).resolve().parents[2]/'output/adventure game 0.1.5.2/main.gd'
s=p.read_text()
s=s.replace('var fullness := 100','var fullness := 100\nvar health := 100.0\nvar hunger_elapsed := 0.0\n@export var resource_seed: int = 0\nvar props: Array[Dictionary] = []\nvar harvest_art: Array[Texture2D] = []\nvar prop_art: Array[Texture2D] = []\nvar status_art: Array[Texture2D] = []\nvar avatar_unarmed: Texture2D\nvar avatar_armed: Texture2D\nvar held_weapon_art: Array[Texture2D] = []\nconst AVATAR_CELL := Vector2(96, 128)\nconst AVATAR_ANCHOR := Vector2(48, 117)\nconst AVATAR_SCALE := 0.72')
s=s.replace('const WALK_STRIDE := 64.0','const WALK_STRIDE := 72.0')
# Preserve generated painting pixels; find empty gutters rather than assume exact tiles.
pos=s.index('func load_art()')
s=s[:pos]+'''func auto_grid(path: String, columns: int, rows: int) -> Array[Texture2D]:
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

''' + s[pos:]
s=s.replace('\tfor texture in traveler_art + npc_art + art + variant_art + walk_art:', '''\tharvest_art = auto_grid("res://assets/harvest-nodes.png", 3, 6)
	prop_art = auto_grid("res://assets/cabin-props.png", 3, 2)
	status_art = auto_grid("res://assets/status-icons.png", 2, 1)
	avatar_unarmed = load_texture("res://assets/traveler-unarmed-12.png")
	avatar_armed = load_texture("res://assets/traveler-armed-12.png")
	held_weapon_art.clear()
	for index in range(6): held_weapon_art.append(load_texture("res://assets/held-weapon-%d.png" % index))
	for texture in traveler_art + npc_art + art + variant_art + walk_art + harvest_art + prop_art:''')
s=s.replace('\tobstacles = [cabin,', '\tprops = [{"p": Vector2(477, 643), "sprite": 1, "height": 49.0, "rect": Rect2(449,625,62,23)}, {"p": Vector2(229,630), "sprite": 3, "height": 46.0, "rect": Rect2(212,614,33,20)}, {"p": Vector2(265,666), "sprite": 4, "height": 34.0, "rect": Rect2(249,654,34,18)}]\n\tobstacles = [cabin,')
s=s.replace('\tfor pool in pools:\n\t\tvar poly', '\tfor prop in props: obstacles.append(prop.rect)\n\tfor pool in pools:\n\t\tvar poly',1)
a=s.index('\tfor p in [Vector2(590, 715)');b=s.index('\n\nfunc add_item',a)
s=s[:a]+'''\tvar supplies := RandomNumberGenerator.new()
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
	return absf(p.y - 760) < 48 or absf(p.x - 1700) < 48

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
		if near_path(p) and rng.randf() < 0.88: continue
		if not walkable(p) or not walkable(p + Vector2(0,30)): continue
		if p.distance_to(npc_home) < 75 or cabin.grow(28).has_point(p): continue
		var crowded := false
		for item in items:
			if item.pos.distance_to(p) < 52: crowded = true; break
		if crowded: continue
		add_item(p,kind)
		items[-1]["variant"] = rng.randi_range(0,2)
		items[-1]["mirror"] = rng.randf() < 0.5
		placed += 1
	if placed < count: push_warning("Resource placement below target: " + kind)

func resource_rect(item: Dictionary) -> Rect2:
	return Rect2(item.pos - Vector2(13,10),Vector2(26,15))
''' + s[b:]
s=s.replace('items.append({"pos": p, "kind": kind, "taken": false})','items.append({"pos": p, "kind": kind, "taken": false, "variant": items.size() % 3, "mirror": false})')
s=s.replace('\tfor npc in [npc_home, npc_position]:','\tfor item in items:\n\t\tif not item.taken and not item.get("dropped",false) and item.kind != "rope" and feet.intersects(resource_rect(item)): return false\n\tfor npc in [npc_home, npc_position]:',1)
s=s.replace('\t\t\tadvance_day(delta)','\t\t\tadvance_vitals(delta)\n\t\t\tadvance_day(delta)',1)
s=s.replace('\tif key == KEY_B:\n', '\tif key == KEY_H:\n\t\tuse_medicine()\n\t\treturn\n\tif key == KEY_B:\n',1)
s=s.replace('Fullness only gives warnings in this version.','Gather berry shrubs to restore fullness.\nH uses medicine to heal; starving drains health.')
s=s.replace('if branches + rocks + ropes >= CAPACITY:', 'if kind != "berry" and branches + rocks + ropes >= CAPACITY:',1)
s=s.replace('\t\t"rope": ropes += 1','\t\t"rope": ropes += 1\n\t\t"berry": fullness = mini(100, fullness + 22)',1)
s=s.replace('notify("Picked up: " + item_name(kind))','notify("Ate forest berries. Fullness +22." if kind == "berry" else ("Gathered: " + item_name(kind)))')
pos=s.index('func advance_day(')
s=s[:pos]+'''func take_damage(amount: float) -> void:
	health = clampf(health - maxf(0, amount), 0, 100)
	if health <= 0 and not won:
		lost = true
		phase = "lost"
		result_text = "Your health ran out. Gather food and prepare better equipment."

func advance_vitals(dt: float) -> void:
	if paused or phase != "day" or won or lost: return
	hunger_elapsed += maxf(0, dt) * 0.06
	var hunger_cost := int(hunger_elapsed)
	if hunger_cost > 0:
		fullness = maxi(0, fullness - hunger_cost)
		hunger_elapsed -= hunger_cost
	if fullness == 0: take_damage(maxf(0, dt) * 1.5)

func use_medicine() -> void:
	if phase != "day" or paused or health >= 100 or medicine <= 0: return
	medicine -= 1
	health = minf(100, health + 40)
	notify("Used medicine. Health +40.")

''' +s[pos:]
a=s.index('\tif power < threat:',s.index('func resolve_night'));b=s.index('\n\tsurvived += 1',a)
s=s[:a]+'''\tif power < threat:
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
''' +s[b:]
s=s.replace('"crystal": "Blue crystal"','"berry": "Berries", "crystal": "Blue crystal"')
s=s.replace('\tif id == "resume":', '\tif id == "heal": use_medicine(); return\n\tif id == "resume":',1)
a=s.index('# Whole painted poses,');b=s.index('func draw_ellipse_shadow',a)
s=s[:a]+'''func avatar_direction(direction: Vector2) -> int:
	return posmod(int(round(atan2(direction.x, direction.y) / (TAU / 12.0))),12)

func avatar_frame() -> int:
	return int(walk_distance / WALK_STRIDE * 8.0) % 8 if moving else 8

func equipped_weapon_index() -> int:
	if weapons.is_empty(): return -1
	for index in range(RECIPES.size()):
		if RECIPES[index][0] == weapons[-1]: return index
	return -1

func draw_traveler(p: Vector2) -> void:
	var direction := avatar_direction(facing)
	var frame := avatar_frame()
	var equipped := equipped_weapon_index()
	var texture := avatar_armed if equipped >= 0 else avatar_unarmed
	var source := Rect2(Vector2(direction * AVATAR_CELL.x,frame * AVATAR_CELL.y),AVATAR_CELL)
	var rect := Rect2(p - AVATAR_ANCHOR * AVATAR_SCALE,AVATAR_CELL * AVATAR_SCALE)
	draw_texture_rect_region(texture,rect,source)
	# Only the visible part of the model-attached weapon is rendered; the hand
	# and body already occlude its hidden parts in the shared 3D depth buffer.
	if equipped >= 0: draw_texture_rect_region(held_weapon_art[equipped],rect,source)

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
		draw_texture_rect(resource_art[row*3+int(item.variant)],Rect2(p-Vector2(14,11),Vector2(28,22)),false)
		return
	var row := 0 if item.kind in ["branch","berry"] else (1 if item.kind == "rock" else 2)
	var height := 38.0 if row != 1 else 30.0
	if item.taken: height *= 0.48
	var texture := harvest_art[row*3+int(item.variant)+(9 if item.taken else 0)]
	ground_patch(1,p+Vector2(0,2),Vector2(51,19),0.22)
	draw_set_transform(p-camera,0,Vector2(-1 if item.mirror else 1,1))
	draw_sprite(texture,Vector2(0,4),height,Color(0.91,0.94,0.86))
	draw_set_transform(-camera)

''' +s[b:]
a=s.index('\tfor i in range(items.size()):',s.index('func _draw()'));b=s.index('\tfor entry in scenery:',a)
s=s[:a]+'\tvar scenery := scenery_entries()\n'+s[b:]
s=s.replace('\t\t\t"cabin": painted_sprite(4, p, 222)','\t\t\t"resource": draw_resource_node(int(entry.index))\n\t\t\t"prop":\n\t\t\t\tvar prop: Dictionary = props[int(entry.index)]\n\t\t\t\tdraw_sprite(prop_art[int(prop.sprite)],p,float(prop.height))\n\t\t\t"cabin": draw_sprite(prop_art[0],p,222)')
s=s.replace('text = "E  Pick up " + item_name(items[int(target.index)].kind)','text = "E  " + ("Eat berries" if items[int(target.index)].kind == "berry" else "Gather " + item_name(items[int(target.index)].kind))')
s=s.replace('\tfor npc in [npc_home, npc_position]: draw_rect', '\tfor item in items:\n\t\tif not item.taken and not item.get("dropped",false) and item.kind != "rope": draw_rect(resource_rect(item),Color("d296c2"),false,1.0)\n\tfor npc in [npc_home, npc_position]: draw_rect',1)
p.write_text(s)
