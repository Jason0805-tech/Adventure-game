from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]; release=root/'output/adventure game 0.1.5';src=Path('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872')
files={'traveler-directions':'82d3ab60-8388-46a3-8b19-5a50fbf1acd2','environment':'257aafd5-0312-4a34-886b-fd25974f9476','npcs':'166c639f-d94d-4f95-b59e-1da510951cd6','materials':'22d9e7a2-6339-4457-a2f1-c135859f9920','ponds':'1699622c-6754-4981-addb-2fc1a817e79e','meadow':'e5da4f13-1901-471a-a649-c85f26c88730','equipment':'d8ae9de0-9ce3-49d4-9fe1-6af8a13fb289','ground-blends':'22fc9bd6-e583-4f9a-93f0-b390cdfa3ed0','tree-variants':'852c8c0b-9812-4fd9-80ed-7b379a4db3eb'}
for name,uid in files.items():shutil.copyfile(src/('exec-'+uid+'.png'),release/'assets'/(name+'.png'))
p=release/'main.gd';s=p.read_text()
s=s.replace('var pond_art: Array[Texture2D] = []','var pond_art: Array[Texture2D] = []\nvar variant_art: Array[Texture2D] = []\nvar equipment_art: Array[Texture2D] = []\nvar blend_art: Array[Texture2D] = []')
s=s.replace('var brush_marks: Array[Dictionary] = []','var ground_details: Array[Dictionary] = []')
s=s.replace('var trail_shapes: Array[PackedVector2Array] = []','')
s=s.replace('func load_grid(path: String, columns: int, rows: int)', 'func load_grid(path: String, columns: int, rows: int, row_cuts: Array = [])')
s=s.replace('var y := int(float(row) * sheet.get_height() / rows)','var y := int(float(row) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row]) * sheet.get_height())')
s=s.replace('var bottom := int(float(row + 1) * sheet.get_height() / rows)','var bottom := int(float(row + 1) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row + 1]) * sheet.get_height())')
s=s.replace('art = load_grid("res://assets/environment.png", 3, 2)','art = load_grid("res://assets/environment.png", 3, 2, [0.0, 0.54, 1.0])')
s=s.replace('resource_art = load_grid("res://assets/materials.png", 3, 3)','resource_art = load_grid("res://assets/materials.png", 3, 3, [0.0, 0.36, 0.67, 1.0])')
s=s.replace('pond_art = load_grid("res://assets/ponds.png", 1, 3)','pond_art = load_grid("res://assets/ponds.png", 1, 3, [0.0, 0.38, 0.71, 1.0])\n\tvariant_art = load_grid("res://assets/tree-variants.png", 3, 2, [0.0, 0.63, 1.0])\n\tequipment_art = load_grid("res://assets/equipment.png", 4, 2)\n\tblend_art = load_grid("res://assets/ground-blends.png", 3, 2)')
s=s.replace('for texture in traveler_art + npc_art + art:', 'for texture in traveler_art + npc_art + art + variant_art:')
a=s.index('\tvar rng := RandomNumberGenerator.new()',s.index('func load_art()'));b=s.index('func sprite_rect(',a)
s=s[:a]+'''	# Stable sparse decals bridge the painted base and object feet without tiling.
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
	var variant := seed_value % 6
	var tex: Texture2D = art[variant] if variant < 3 else variant_art[variant - 3]
	var height := 148.0 + seed_value % 39
	var warmth := float(seed_value % 11) / 180.0
	var tint := Color(1.0 - warmth * 0.35, 1.0 - warmth * 0.15, 1.0 - warmth, 0.42 if faded else 1.0)
	# Mirror around the shared ground anchor, never via a negative texture rectangle.
	draw_set_transform(-camera + p, 0, Vector2(-1 if seed_value % 2 else 1, 1))
	draw_sprite(tex, Vector2(0, 5), height, tint)
	draw_set_transform(-camera)

''' +s[b:]
s=s.replace('draw_sprite(traveler_art[frame], p, 67)', 'draw_sprite(traveler_art[frame], p, 75)')
s=s.replace('draw_sprite(npc_art[frame], p, 69)', 'draw_sprite(npc_art[frame], p, 76)')
a=s.index('\t\tif sword:',s.index('func person('));b=s.index('\telif not npc_art',a)
s=s[:a]+'''		if sword and not equipment_art.is_empty():
			var weapon_index := 0
			if not weapons.is_empty():
				for i in range(RECIPES.size()):
					if RECIPES[i][0] == weapons[-1]: weapon_index = i
			var side := -1.0 if facing.x < 0 else 1.0
			draw_sprite(equipment_art[weapon_index], p + Vector2(side * 21, -6), 35)
''' +s[b:]
a=s.index('func draw_ellipse_shadow(');b=s.index('func draw_collision_overlay()',a)
s=s[:a]+'''func draw_ellipse_shadow(p: Vector2) -> void:
	var progress := day_fraction()
	var cast := Vector2(lerpf(7, -7, progress), 1)
	ground_patch(3, p + cast, Vector2(39 + absf(progress - 0.5) * 21, 18), 0.56)

''' +s[b:]
s=s.replace('false, Color("b8d5c9"))', 'false)')
a=s.index('\t# Broad meandering strokes');b=s.index('\tfor i in range(pools.size()):',a)
s=s[:a]+'''	for detail in ground_details:
		ground_patch(detail.variant, detail.p, detail.size, 0.36)
	for tree in trees:
		ground_patch(0 if int(tree.x) % 2 else 1, tree + Vector2(0, 3), Vector2(94, 39), 0.58)
	ground_patch(2, Vector2(350, 634), Vector2(251, 65), 0.68)
	ground_patch(4, Vector2(354, 683), Vector2(113, 65), 0.46)
''' +s[b:]
s=s.replace('\t\tif not pond_art.is_empty(): draw_texture_rect(pond_art[i], pools[i], false)','\t\tground_patch(0, pools[i].get_center(), pools[i].size + Vector2(19, 17), 0.25)\n\t\tif not pond_art.is_empty(): draw_texture_rect(pond_art[i], pools[i], false)')
s=s.replace('var size := Vector2(34, 27) if row == 0 else Vector2(29, 24)','var size := Vector2(36, 28) if row == 0 else Vector2(31, 25)\n\t\t\tground_patch(3, p + Vector2(1, 6), Vector2(31, 13), 0.22)')
s=s.replace('painted_sprite((int(p.x) + int(p.y)) % 3, p + Vector2(0, 5), 117 + int(p.x) % 24, false, Color(1, 1, 1, 0.42 if faded else 1.0))','varied_tree(p, faded)')
s=s.replace('"shrub": painted_sprite(3, p + Vector2(0, 9), 57)','''"shrub":
				var shrub_index := absi(int(p.x + p.y)) % 4
				var tex: Texture2D = art[3] if shrub_index == 0 else variant_art[shrub_index + 2]
				draw_sprite(tex, p + Vector2(0, 9), 53 + absi(int(p.x)) % 13)''')
s=s.replace('func label_at(p: Vector2, text: String, size: int = 18, color := Color("e6ecd9"))','func label_at(p: Vector2, text: String, size: int = 18, color := Color("35483d"))')
s=s.replace('Color("203d40")','Color("e9dcb6")').replace('Color("284c49")','Color("e6d8b3")').replace('Color("a0b7a7")','Color("657259")').replace('Color("f0d192")','Color("875c31")').replace('Color("b5c7b9")','Color("69795e")')
s=s.replace('Color("f9eccb")','Color("304c3c")').replace('Color("fff0cc")','Color("304c3c")').replace('Color("fff2cc")','Color("304c3c")')
# Keep map marker easy to read on parchment.
s=s.replace('draw_circle(map_pos + player * map_scale, 4, Color.WHITE)','draw_circle(map_pos + player * map_scale, 4, Color("28566a"))').replace('White: you / Gold: camp','Blue: you / Gold: camp')
# Put all new inventory objects into the playable interface.
s=s.replace('label_at(base + Vector2(30, y + 17), str(i + 1)', 'draw_texture_rect(equipment_art[i], Rect2(base + Vector2(29, y + 1), Vector2(33, 39)), false)\n\t\t\tlabel_at(base + Vector2(73, y + 17), str(i + 1)')
s=s.replace('label_at(base + Vector2(30, y + 37), cost','label_at(base + Vector2(73, y + 37), cost')
s=s.replace('label_at(base + Vector2(30, 99 + i * 44), ["Branches", "Rocks", "Ropes"]', 'draw_texture_rect(resource_art[i * 3], Rect2(base + Vector2(30, 76 + i * 44), Vector2(33, 29)), false)\n\t\t\tlabel_at(base + Vector2(79, 99 + i * 44), ["Branches", "Rocks", "Ropes"]')
s=s.replace('var counts := {}','''if not equipment_art.is_empty():
			draw_texture_rect(equipment_art[6], Rect2(base + Vector2(472, 182), Vector2(26, 30)), false)
			draw_texture_rect(equipment_art[7], Rect2(base + Vector2(510, 181), Vector2(23, 31)), false)
		var counts := {}''')
p.write_text(s)
