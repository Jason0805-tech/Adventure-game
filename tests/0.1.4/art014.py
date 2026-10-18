from pathlib import Path
import shutil
base=Path('outputs/adventure game 0.1.3'); dst=Path('outputs/adventure game 0.1.4')
dst.mkdir(exist_ok=True)
for name in ['main.gd','main.tscn','project.godot','tests.gd','ENGINE_LICENSES.txt']:
 shutil.copyfile(base/name,dst/name)
(dst/'assets').mkdir(exist_ok=True)
assets=Path('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872')
shutil.copyfile(assets/'exec-98926972-8d93-4724-9682-10c382695985.png',dst/'assets/woodland-atlas.png')
shutil.copyfile(assets/'exec-a9022217-3453-4dd7-a666-d4bd7e3e3607.png',dst/'assets/meadow.png')
s=(dst/'main.gd').read_text().replace('0.1.3','0.1.4')
s=s.replace('var font: Font','''var font: Font
var art: Array[Texture2D] = []
var meadow: Texture2D
var brush_marks: Array[Dictionary] = []
var moving := false

func load_art() -> void:
	# Trim alpha within atlas regions at load time, keeping each original painted sprite.
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/woodland-atlas.png"))
	var regions := [Rect2i(0, 0, 530, 512), Rect2i(530, 0, 560, 512), Rect2i(1100, 0, 436, 512), Rect2i(0, 512, 512, 512), Rect2i(512, 512, 430, 512), Rect2i(950, 512, 586, 512)]
	for region in regions:
		var part := sheet.get_region(region)
		art.append(ImageTexture.create_from_image(part.get_region(part.get_used_rect())))
	meadow = ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://assets/meadow.png")))
	var rng := RandomNumberGenerator.new()
	rng.seed = 14014
	for i in range(1900):
		var p := Vector2(rng.randf_range(85, 2080), rng.randf_range(220, 1340))
		if (absf(p.y - 760) < 48 and p.x < 2030) or (absf(p.x - 1700) < 43) or (absf(p.y - 280) < 35 and p.x > 1700):
			brush_marks.append({"p": p, "length": rng.randf_range(4, 26), "width": rng.randf_range(1, 5), "color": Color("d9c38c") if i % 2 else Color("ac9c76")})

func painted_sprite(index: int, foot: Vector2, height: float, flip: bool = false, tint: Color = Color.WHITE) -> void:
	if art.is_empty(): return
	var tex := art[index]
	var width := height * tex.get_width() / tex.get_height()
	var rect := Rect2(foot - Vector2(width * 0.5, height), Vector2(width, height))
	if flip:
		rect.position.x += width
		rect.size.x = -width
	draw_texture_rect(tex, rect, false, tint)

func paper_panel(rect: Rect2, fill: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = Color("a68e62")
	style.shadow_color = Color(0.02, 0.08, 0.09, 0.18)
	style.shadow_size = 4
	draw_style_box(style, rect)
''')
s=s.replace('\tfont = ThemeDB.fallback_font','\tfont = ThemeDB.fallback_font\n\tload_art()',1)
s=s.replace('\tvar dt := minf(delta, 0.05)','\tmoving = false\n\tvar dt := minf(delta, 0.05)',1)
s=s.replace('\t\t\tmove_player(direction, dt)','\t\t\tmoving = direction.length_squared() > 0\n\t\t\tmove_player(direction, dt)',1)
a=s.index('func person(');b=s.index('func draw_ellipse_shadow(',a)
s=s[:a]+'''func person(p: Vector2, _color: Color, title: String, is_player: bool = false) -> void:
	draw_ellipse_shadow(p)
	var bob := sin(elapsed * 13.0) * 2.0 if is_player and moving else sin(elapsed * 2.0) * 0.6
	var index := 2 if is_player else (3 if title == "Rowan" else 4)
	painted_sprite(index, p + Vector2(0, 17 + bob), 83 if is_player else 79, is_player and facing.x < 0)
	if is_player:
		draw_arc(p + Vector2(0, 16), 18, 0.05, PI - 0.05, 20, Color(0.98, 0.88, 0.6, 0.8), 2, true)
		if sword:
			draw_line(p + Vector2(20, 0), p + Vector2(29, -24), Color("d8e3da"), 4, true)
			draw_line(p + Vector2(16, -4), p + Vector2(27, 0), Color("c89d50"), 3, true)
	else:
		label_at(p + Vector2(-26, -74), title, 16, Color("fff2cc"))

''' + s[b:]
a=s.index('\tdraw_rect(Rect2(Vector2.ZERO, WORLD)',s.index('func _draw()'));b=s.index('\tfor item in items:',a)
s=s[:a]+'''	if meadow != null:
		draw_texture_rect(meadow, Rect2(Vector2.ZERO, WORLD), false, Color("b8d5c9"))
	else:
		draw_rect(Rect2(Vector2.ZERO, WORLD), Color("71927b"))
	# Broad meandering strokes form trails, with stable dry-brush flecks.
	var paths := [PackedVector2Array([Vector2(100,760),Vector2(470,760),Vector2(850,765),Vector2(1200,752),Vector2(1640,760),Vector2(2030,760)]), PackedVector2Array([Vector2(1700,1310),Vector2(1693,1000),Vector2(1700,760),Vector2(1707,470),Vector2(1700,280),Vector2(2070,280)])]
	for path in paths:
		draw_polyline(path, Color("91a17c"), 116, true)
		draw_polyline(path, Color("b6ac81"), 99, true)
		draw_polyline(path, Color("c3b48a"), 76, true)
	for mark in brush_marks:
		draw_line(mark.p, mark.p + Vector2(mark.length, -2), mark.color, mark.width, true)
	# Lake keeps its original rectangular collision footprint; layered irregular shore softens it.
	var shore := PackedVector2Array([Vector2(920,365),Vector2(972,338),Vector2(1180,345),Vector2(1250,377),Vector2(1262,535),Vector2(1220,587),Vector2(964,590),Vector2(905,544)])
	draw_colored_polygon(shore, Color("a9b995"))
	draw_rect(pond, Color("3d7c87"))
	for i in range(17):
		var offset := sin(elapsed * 0.7 + i) * 6
		var start := pond.position + Vector2(12 + (i * 37 % 110) + offset, 12 + i * 12)
		draw_line(start, start + Vector2(65 + i % 4 * 24, 0), Color(0.65, 0.84, 0.8, 0.24), 3, true)
	label_at(Vector2(1580, 1360), "SOUTHERN WOODS", 19, Color("f9eccb"))
	label_at(Vector2(1580, 195), "NORTHERN TRAIL", 19, Color("f9eccb"))
	label_at(Vector2(940, 325), "STILLWATER LAKE", 18, Color("f9eccb"))
''' +s[b:]
a=s.index('\tdraw_rect(Rect2(gate - Vector2(52, 80)');b=s.index('\tvar target := nearest_target()',a)
s=s[:a]+'''	# Depth-sort tall objects by their feet so travelers can pass behind tree canopies.
	var scenery: Array[Dictionary] = []
	for tree in trees: scenery.append({"p": tree, "kind": "tree"})
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
				var faded := player.y < p.y and absf(player.x - p.x) < 65 and p.y - player.y < 150
				painted_sprite(0, p + Vector2(0, 23), 144 + int(p.x) % 27, int(p.x) % 2 == 0, Color(1, 1, 1, 0.48 if faded else 1.0))
			"cabin": painted_sprite(1, p, 233)
			"gate": painted_sprite(5, p, 155)
			"Rowan": person(p, Color.WHITE, "Rowan")
			"Ash": person(p, Color.WHITE, "Ash")
			"player": person(p, Color.WHITE, "", true)
	label_at(Vector2(254, 665), "TRAVELERS CAMP", 18, Color("fff0cc"))
''' +s[b:]
s=s.replace('player + Vector2(-40, -66)','player + Vector2(-40, -91)')
s=s.replace('draw_rect(rect, Color("476859") if enabled else Color("2d4039"))','paper_panel(rect, Color("426d67") if enabled else Color("304743"), 8)')
s=s.replace('draw_rect(Rect2(0, 0, screen.x, 118), Color("172c2b"))','paper_panel(Rect2(12, 8, screen.x - 24, 108), Color("203d40"))')
s=s.replace('draw_rect(Rect2(0, screen.y - 46, screen.x, 46), Color("172c2b"))','paper_panel(Rect2(12, screen.y - 45, screen.x - 24, 38), Color("203d40"), 8)')
s=s.replace('draw_rect(Rect2(map_pos, Vector2(156, 108)), Color("1c3530"))','paper_panel(Rect2(map_pos - Vector2(8, 8), Vector2(172, 124)), Color("284c49"))')
s=s.replace('draw_rect(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("233a32"))','paper_panel(Rect2(20, screen.y - 100, screen.x - 40, 42), Color("284c49"), 8)')
s=s.replace('draw_rect(Rect2(base, Vector2(720, 530)), Color("203b36"))','paper_panel(Rect2(base, Vector2(720, 530)), Color("203d40"), 16)')
(dst/'main.gd').write_text(s)
p=dst/'project.godot';p.write_text(p.read_text().replace('0.1.3','0.1.4'))
(dst/'README.txt').write_text('''FOREST WANDERER 0.1.4 - PAINTED WOODLAND EDITION
Open Forest Wanderer.app to play, or import project.godot in Godot 4.7.

WASD / Arrow keys: move. E: talk / gather. B: backpack. C: craft.
Esc: close an open panel; Esc again: pause. 1/2/3: choose a night action.
Survive three nights. Each day lasts 90 seconds. Panels do not stop the clock.

NEW ART: Original painterly woodland sprites, textured meadow, brushed trails,
painted cabin and stone gate, animated traveler bobbing, depth-sorted trees,
soft framed menus. Trees become translucent when covering the player.
The English interface and 0.1.3 survival rules remain intact.

This is an early art pass. Characters use one painted pose with mirrored facing
and a walking bob, not full directional animation. Materials and water still
use simple drawn shapes. There is no save system yet.

Art: generated with the built-in imagegen tool. Prompts: ART_PROMPTS.txt.
Engine license: ENGINE_LICENSES.txt.
''')
print(dst.resolve())
