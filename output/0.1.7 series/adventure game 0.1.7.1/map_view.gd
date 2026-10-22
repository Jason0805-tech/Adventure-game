extends RefCounted
## World map (M). Shows only ground the player has actually explored; the rest
## stays under paper fog. Key places get their own painted marks once seen.
## The world keeps running while the map is open: checking it is a risk.

const CELL := 25.0
const REVEAL_RADIUS := 270.0
const FOG := Color("d9cba3")
const FOG_EDGE := Color("cbbb8f")
const INK := Color("35483d")
const RED := Color("b7574a")
const GOLD := Color("d39b3f")

var cols := 0
var rows := 0
var explored := PackedByteArray()
var explored_cells := 0
var _last_reveal := Vector2.INF

func setup(world: Vector2) -> void:
	cols = ceili(world.x / CELL)
	rows = ceili(world.y / CELL)
	explored = PackedByteArray()
	explored.resize(cols * rows)
	explored.fill(0)
	explored_cells = 0
	_last_reveal = Vector2.INF

func reveal(p: Vector2, radius: float = REVEAL_RADIUS) -> void:
	if _last_reveal != Vector2.INF and p.distance_to(_last_reveal) < 10.0: return
	_last_reveal = p
	var c0 := Vector2i(floori((p.x - radius) / CELL), floori((p.y - radius) / CELL))
	var c1 := Vector2i(floori((p.x + radius) / CELL), floori((p.y + radius) / CELL))
	for y in range(maxi(0, c0.y), mini(rows - 1, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(cols - 1, c1.x) + 1):
			var center := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if center.distance_to(p) <= radius and explored[y * cols + x] == 0:
				explored[y * cols + x] = 1
				explored_cells += 1

func seen(p: Vector2) -> bool:
	var x := floori(p.x / CELL)
	var y := floori(p.y / CELL)
	if x < 0 or y < 0 or x >= cols or y >= rows: return false
	return explored[y * cols + x] == 1

func percent() -> int:
	return roundi(100.0 * explored_cells / maxf(1, cols * rows))

func _to_map(p: Vector2, area: Rect2, world: Vector2) -> Vector2:
	return area.position + p / world * area.size

func _diamond(game: Variant, c: Vector2, r: float, color: Color) -> void:
	game.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)

func draw(game: Variant, screen: Vector2) -> void:
	var world: Vector2 = game.WORLD
	var mobile: bool = game.mobile.enabled
	game.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.02, 0.06, 0.07, 0.55))
	var margin := Vector2(60, 70) if not mobile else Vector2(70, 40)
	var available := screen - margin * 2.0 - Vector2(0, 70)
	var scale: float = minf(available.x / world.x, available.y / world.y)
	var size: Vector2 = world * scale
	var area := Rect2((screen - size) * 0.5 + Vector2(0, 18), size)
	game.paper_panel(area.grow(18).grow_individual(0, 52, 0, 40), Color("e9dcb6"), 14)
	var title_size := 26 if mobile else 20
	game.label_at(area.position + Vector2(0, -22), "FOREST MAP   ·   explored %d%%" % percent(), title_size)
	# Painted ground, water and trees at map scale.
	game.draw_texture_rect(game.meadow, area, false)
	for i in range(game.pools.size()):
		var pool: Rect2 = game.pools[i]
		game.draw_texture_rect(game.pond_art[i], Rect2(_to_map(pool.position, area, world), pool.size * scale), false)
	for tree in game.trees:
		if game.tree_live(tree):
			game.draw_circle(_to_map(tree, area, world), maxf(2.5, 26.0 * scale), Color(0.16, 0.33, 0.25, 0.82))
	var cabin := _to_map(Vector2(350, 625), area, world)
	game.draw_rect(Rect2(cabin - Vector2(12, 8) * scale * 3.0, Vector2(24, 16) * scale * 3.0), Color("a5563a"))
	# Fog over everything not yet explored.
	var cell: Vector2 = Vector2(CELL, CELL) * scale
	for y in range(rows):
		for x in range(cols):
			if explored[y * cols + x] == 1: continue
			var r := Rect2(area.position + Vector2(x, y) * cell, cell + Vector2(0.6, 0.6)).intersection(area)
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < cols and ny < rows and explored[ny * cols + nx] == 1: edge = true
			game.draw_rect(r, FOG_EDGE if edge else FOG)
	# Key places. Camp is always known; the rest appear once explored.
	var unit: float = 10.0 if not mobile else 15.0
	var camp := _to_map(game.CAMP, area, world)
	game.draw_colored_polygon(PackedVector2Array([camp + Vector2(0, -unit * 1.3), camp + Vector2(unit * 1.1, unit * 0.7), camp + Vector2(-unit * 1.1, unit * 0.7)]), Color("a5563a"))
	var beacon: Variant = game.beacon
	var beacon_pos := _to_map(beacon.BEACON_POS, area, world)
	if seen(beacon.BEACON_POS):
		var lit: bool = beacon.stage in ["igniting", "lit"]
		if lit: game.draw_circle(beacon_pos, unit * 1.8, Color(1.0, 0.75, 0.35, 0.35))
		for k in range(8):
			var a := TAU * k / 8.0
			game.draw_line(beacon_pos, beacon_pos + Vector2(cos(a), sin(a)) * unit * (1.35 if k % 2 == 0 else 0.8), GOLD, 3.0, true)
		game.draw_circle(beacon_pos, unit * 0.45, Color("fff0b5") if lit else INK)
	var parts := [[beacon.RUNE_POS, beacon.rune_open], [beacon.SHRINE_POS, beacon.core_taken], [beacon.glint, beacon.lens_found]]
	for part in parts:
		if not seen(part[0]): continue
		var c := _to_map(part[0], area, world)
		_diamond(game, c, unit * 0.95, INK)
		_diamond(game, c, unit * 0.65, Color("9a8d6b") if part[1] else Color("6fb6a8"))
	for bench in game.workbenches:
		if seen(bench.p):
			var b := _to_map(bench.p, area, world)
			game.draw_rect(Rect2(b - Vector2.ONE * unit * 0.45, Vector2.ONE * unit * 0.9), Color("8a6a43"))
	# The traveler, pointing where they face.
	var me := _to_map(game.player, area, world)
	var f: Vector2 = game.facing.normalized() if game.facing.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-f.y, f.x)
	var pulse: float = 0.5 + 0.5 * sin(float(game.elapsed) * 5.0)
	game.draw_circle(me, unit * (1.2 + pulse * 0.5), Color(0.72, 0.34, 0.29, 0.25))
	game.draw_colored_polygon(PackedVector2Array([me + f * unit * 1.2, me - f * unit * 0.6 + side * unit * 0.75, me - f * unit * 0.6 - side * unit * 0.75]), RED)
	# Legend: painted marks (no special glyphs; the web font may lack them).
	var legend_y: float = area.end.y + (34 if mobile else 26)
	var text_size := 22 if mobile else 15
	# Shrink the legend until it fits inside the map panel on narrow phones.
	var legend_width := 0.0
	for label in ["You", "Camp", "Beacon", "Beacon part (grey = taken)", "Workbench"]:
		legend_width += game.font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + unit * 4.6
	while legend_width > area.size.x and text_size > 12:
		legend_width -= 5.0 * game.font.get_string_size("Beacon part (grey = taken)YouCampBeaconWorkbench", HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x / 51.0
		text_size -= 1
	var x: float = area.position.x + 4
	var mark_y: float = legend_y - text_size * 0.35
	var items := [["you", "You"], ["camp", "Camp"], ["beacon", "Beacon"], ["part", "Beacon part (grey = taken)"], ["bench", "Workbench"]]
	for item in items:
		var c := Vector2(x + unit, mark_y)
		match item[0]:
			"you": game.draw_colored_polygon(PackedVector2Array([c + Vector2(unit, 0), c + Vector2(-unit * 0.6, unit * 0.7), c + Vector2(-unit * 0.6, -unit * 0.7)]), RED)
			"camp": game.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -unit), c + Vector2(unit, unit * 0.7), c + Vector2(-unit, unit * 0.7)]), Color("a5563a"))
			"beacon":
				for k in range(8):
					var a := TAU * k / 8.0
					game.draw_line(c, c + Vector2(cos(a), sin(a)) * unit * (1.0 if k % 2 == 0 else 0.6), GOLD, 2.0, true)
			"part":
				_diamond(game, c, unit * 0.8, INK); _diamond(game, c, unit * 0.55, Color("6fb6a8"))
			"bench": game.draw_rect(Rect2(c - Vector2.ONE * unit * 0.45, Vector2.ONE * unit * 0.9), Color("8a6a43"))
		game.label_at(Vector2(x + unit * 2.4, legend_y), item[1], text_size, Color("53634d"))
		x += unit * 2.4 + game.font.get_string_size(item[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x + unit * 2.2
	var close_size := Vector2(170, 52) if mobile else Vector2(140, 38)
	game.ui_button(Rect2(Vector2(area.end.x - close_size.x, area.position.y - 50 if not mobile else area.position.y - 58), close_size), "M  Close" if not mobile else "Close", "map_close")
