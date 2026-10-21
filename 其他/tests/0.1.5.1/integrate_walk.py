from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[2]; p=root/'output/adventure game 0.1.5.1'; g=Path('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872')
for name,id in {'walk-right':'3153b670-8a9f-4d08-a1b4-1a3ccfec8965','walk-left':'7e45f17e-d36e-4aba-a1d6-08bb6b0278ef','walk-up':'a36997d3-0d6e-44ed-9448-3dcc0471b918','walk-down':'b1c5574e-820e-4d04-a3d5-3263f8fb25e6','ponds':'7d775aac-178c-4927-8be8-abbe290f632a'}.items(): shutil.copyfile(g/('exec-'+id+'.png'),p/'assets'/(name+'.png'))
f=p/'main.gd'; s=f.read_text().replace('var moving := false','var moving := false\nvar walk_art: Array[Texture2D] = []\nvar walk_scales: Dictionary = {}\nvar walk_distance := 0.0\nconst WALK_STRIDE := 128.0')
s=s.replace('row_cuts: Array = [])','row_cuts: Array = [], column_cuts: Array = [])')
s=s.replace('var x := int(float(col) * sheet.get_width() / columns)','var x := int(float(col) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col])')
s=s.replace('var right := int(float(col + 1) * sheet.get_width() / columns)','var right := int(float(col + 1) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col + 1])')
s=s.replace('3, 2, [0.0, 0.54, 1.0])','3, 2, [0.0, 552.0/1024, 1.0], [[0,520,1024,1536],[0,499,1024,1536]])')
s=s.replace('1, 3, [0.0, 0.38, 0.71, 1.0])','3, 1)')
s=s.replace('3, 2, [0.0, 0.61, 1.0])','3, 2, [0.0, 624.0/1024, 1.0], [[0,512,1024,1536],[0,516,1024,1536]])')
s=s.replace('"res://assets/ground-blends.png", 3, 2)','"res://assets/ground-blends.png", 3, 2, [], [[0,512,1024,1536],[0,522,1024,1536]])')
s=s.replace('\tfor texture in traveler_art + npc_art + art + variant_art:', '\twalk_art.clear()\n\tfor direction in ["down", "left", "right", "up"]:\n\t\tvar frames := load_grid("res://assets/walk-" + direction + ".png", 6, 1)\n\t\tvar mean_height := 0.0\n\t\tfor frame in frames: mean_height += frame.get_height() / 6.0\n\t\tfor frame in frames: walk_scales[frame] = 75.0 / mean_height\n\t\twalk_art.append_array(frames)\n\tfor texture in traveler_art + npc_art + art + variant_art + walk_art:')
s=s.replace('\t\tfoot_anchors[texture] =', '\t\t# Walking pivots use the torso, so alternating boots cannot drag the body sideways.\n\t\tif texture in walk_art:\n\t\t\ttotal = 0.0\n\t\t\tweighted_x = 0.0\n\t\t\tfor y in range(int(pixels.get_height() * 0.3), int(pixels.get_height() * 0.65)):\n\t\t\t\tfor x in range(pixels.get_width()):\n\t\t\t\t\tvar alpha := pixels.get_pixel(x, y).a\n\t\t\t\t\tif alpha > 0.5:\n\t\t\t\t\t\ttotal += alpha\n\t\t\t\t\t\tweighted_x += (x + 0.5) * alpha\n\t\tfoot_anchors[texture] =')
s=s.replace('\t\t\tmoving = player.distance_to(previous) > 0.1','\t\t\tupdate_walk(player.distance_to(previous))')
s=s.replace('func _process(delta: float)', 'func update_walk(distance: float) -> void:\n\tmoving = distance > 0.1\n\tif moving: walk_distance = fposmod(walk_distance + distance, WALK_STRIDE)\n\nfunc walk_frame() -> int:\n\treturn mini(5, int(walk_distance / WALK_STRIDE * 6.0))\n\nfunc _process(delta: float)')
s=s.replace('\t\tif moving and int(elapsed * 7.0) % 2 == 1: frame += 4\n\t\tdraw_sprite(traveler_art[frame], p, 75)','\t\tif moving and not walk_art.is_empty():\n\t\t\tvar texture := walk_art[frame * 6 + walk_frame()]\n\t\t\tdraw_sprite(texture, p, texture.get_height() * walk_scales[texture])\n\t\telse:\n\t\t\tdraw_sprite(traveler_art[frame], p, 75)')
a=s.index('func draw_ellipse_shadow('); b=s.index('\nfunc draw_collision_overlay',a)
s=s[:a]+'''func draw_ellipse_shadow(p: Vector2) -> void:
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
''' +s[b:]
f.write_text(s)
