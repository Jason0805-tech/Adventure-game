extends RefCounted
## v0.1.8 Quest & Progression: journal, discoveries, supply caches,
## exploration milestones and recipes learned through exploration.

const Data = preload("res://item_data.gd")

# Landmarks are discovered the first time the player walks near them.
# "learn" teaches a recipe; "give" hands out a small bundle.
const LANDMARKS := [
	{"id": "stillwater", "name": "Stillwater Lake", "pos": Vector2(1085, 465), "radius": 210.0, "give": {"rope": 3}, "note": "Something glints near the south shore."},
	{"id": "east_pool", "name": "Eastern Pool", "pos": Vector2(1485, 447), "radius": 160.0, "give": {"fish": 1}, "note": "Fish rise in the shallows."},
	{"id": "south_pond", "name": "Southern Pond", "pos": Vector2(660, 1155), "radius": 170.0, "give": {"medicine": 1}, "note": "Someone left medicine by the reeds."},
	{"id": "lookout", "name": "Scout's Lookout", "pos": Vector2(1280, 970), "radius": 170.0, "give": {"log": 2}, "note": "Ash keeps spare timber here."},
	{"id": "southern_woods", "name": "Southern Woods", "pos": Vector2(1580, 1330), "radius": 230.0, "give": {"ore": 2}, "note": "Iron ore lies loose among the roots."},
	{"id": "beacon", "name": "The Old Beacon", "pos": Vector2(1890, 372), "radius": 220.0, "learn": "crystal", "note": "Runes on the tower describe a protective ward."},
	{"id": "rune", "name": "Rune Stone", "pos": Vector2(1985, 1195), "radius": 190.0, "learn": "iron_axe", "note": "The carvings show how to forge an iron axe."},
	{"id": "shrine", "name": "Forest Shrine", "pos": Vector2(690, 385), "radius": 190.0, "learn": "amazing_sword", "note": "An old blade-smith's mark is cut into the altar."},
]
# Weathered supply crates in the far corners of the forest.
const CACHES := [Vector2(2075, 640), Vector2(205, 1335), Vector2(1475, 1395), Vector2(980, 175)]
const CACHE_LOOT := [
	{"medicine": 1, "fish": 2},
	{"crystal": 1, "torch": 1},
	{"medicine": 1, "ore": 2},
	{"fish": 2, "crystal": 1},
]
const MILESTONES := [
	{"percent": 25, "give": {"fish": 2}},
	{"percent": 50, "give": {"medicine": 1}},
	{"percent": 75, "give": {"crystal": 1}},
]
const BANNER_TIME := 3.6

var discovered: Dictionary = {}
var learned: Dictionary = {}
var opened: Array[bool] = []
var milestones_done: Array[bool] = []
var steps_done: Dictionary = {}
var banner_title := ""
var banner_text := ""
var banner_time := 0.0
var banner_queue: Array = [] # events that happen together play one after another
var _initialized_steps := false

func setup(game: Variant) -> void:
	discovered.clear(); learned.clear(); steps_done.clear()
	opened.clear(); for i in range(CACHES.size()): opened.append(false)
	milestones_done.clear(); for i in range(MILESTONES.size()): milestones_done.append(false)
	banner_title = ""; banner_text = ""; banner_time = 0.0; banner_queue.clear()
	_initialized_steps = false

func recipe_learned(recipe: Dictionary) -> bool:
	var need: String = str(recipe.get("learn", ""))
	return need.is_empty() or learned.has(recipe.id)

func learn_place(recipe_id: String) -> String:
	for mark in LANDMARKS:
		if str(mark.get("learn", "")) == recipe_id: return str(mark.name)
	return ""

func _give(game: Variant, bundle: Dictionary, at: Vector2) -> String:
	var parts: Array[String] = []
	for id in bundle:
		game.give_item(id, int(bundle[id]), at)
		parts.append("+%d %s" % [int(bundle[id]), Data.label(id)])
	return ", ".join(parts)

func show_banner(title: String, text: String) -> void:
	if banner_time > 0.0:
		if banner_queue.size() < 6: banner_queue.append([title, text])
		return
	banner_title = title; banner_text = text; banner_time = BANNER_TIME

func tick(dt: float) -> void:
	banner_time = maxf(0.0, banner_time - dt)
	if banner_time <= 0.0 and not banner_queue.is_empty():
		var next: Array = banner_queue.pop_front()
		show_banner(next[0], next[1])

# --- Main quest steps (derived from the real game state) -------------------
func quest_steps(game: Variant) -> Array:
	var b: Variant = game.beacon
	var repaired: bool = b.stage in ["repaired", "igniting", "lit"]
	return [
		{"id": "talk", "text": "Talk to Rowan at camp", "done": bool(game.quest)},
		{"id": "lens", "text": "Beacon lens: fish at the lake glint", "done": b.lens_found},
		{"id": "gear", "text": "Bronze gear: break the rune rock (pickaxe)", "done": b.rune_open},
		{"id": "core", "text": "Ember core: shrine west of the lake", "done": b.core_taken},
		{"id": "repair", "text": "Repair the beacon: 4 logs + 2 ore", "done": repaired},
		{"id": "light", "text": "Light it after dark and guard it 60 s", "done": b.stage == "lit"},
	]

func update(game: Variant, _dt: float) -> void:
	# The banner timer is advanced by main._process (it also runs in menus).
	if not game.active_exploration(): return
	# Landmarks.
	for mark in LANDMARKS:
		if discovered.has(mark.id): continue
		if game.player.distance_to(mark.pos) > float(mark.radius): continue
		discovered[mark.id] = true
		var reward := ""
		if mark.has("learn"):
			learned[mark.learn] = true
			reward = "New recipe: " + Data.label(mark.learn)
		elif mark.has("give"):
			reward = _give(game, mark.give, game.player + Vector2(18, 12))
		show_banner("DISCOVERED: " + str(mark.name), str(mark.note) + "  " + reward)
		game.map_view.reveal(mark.pos, 200.0)
		print("DISCOVERED ", mark.id)
	# Exploration milestones.
	var explored: int = game.map_view.percent()
	for i in range(MILESTONES.size()):
		if milestones_done[i] or explored < int(MILESTONES[i].percent): continue
		milestones_done[i] = true
		show_banner("EXPLORER: %d%% OF THE FOREST MAPPED" % int(MILESTONES[i].percent), _give(game, MILESTONES[i].give, game.player + Vector2(-18, 12)))
	# Quest steps: announce each newly completed step once.
	for step in quest_steps(game):
		if not step.done or steps_done.has(step.id): continue
		steps_done[step.id] = true
		if _initialized_steps: show_banner("QUEST UPDATED", step.text + "  - done")
	_initialized_steps = true

# --- Supply caches -------------------------------------------------------------
func cache_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(CACHES.size()):
		if not opened[i]: result.append({"pos": CACHES[i], "kind": "cache", "index": i})
	return result

func open_cache(game: Variant, index: int) -> void:
	if index < 0 or index >= CACHES.size() or opened[index]: return
	opened[index] = true
	show_banner("SUPPLY CACHE %d / %d" % [opened_count(), CACHES.size()], _give(game, CACHE_LOOT[index], CACHES[index] + Vector2(0, 32)))
	print("CACHE_OPENED ", index)

func opened_count() -> int:
	var n := 0
	for o in opened: if o: n += 1
	return n

func next_gear_hint(game: Variant) -> String:
	var bag: Variant = game.bag
	if bag.count("stone_axe") == 0 and bag.count("iron_axe") == 0: return "Craft a stone axe in the field (C): 2 branches, 3 rocks, 1 fiber."
	if game.workbenches.size() <= 1 and bag.count("workbench") == 0 and bag.count("pickaxe") == 0: return "Use the camp workbench (E) for a pickaxe, fishing rod and stone sword."
	if bag.count("pickaxe") == 0: return "Craft a pickaxe at a workbench to mine ore and break the rune rock."
	if bag.count("fishing_rod") == 0: return "Craft a fishing rod at a workbench to fish up the beacon lens."
	if bag.count("iron_axe") == 0:
		return "Iron axe: craft it at a workbench." if learned.has("iron_axe") else "Discover the Rune Stone to learn the iron axe."
	if bag.count("amazing_sword") == 0:
		return "Upgrade a stone sword at a workbench." if learned.has("amazing_sword") else "Discover the Forest Shrine to learn the upgraded sword."
	return "Your gear is fully upgraded. Light the beacon!"

# --- Drawing -------------------------------------------------------------------
func _check(game: Variant, c: Vector2, done: bool, s: float) -> void:
	if done:
		game.draw_circle(c, s, Color("6b8f5a"))
		game.draw_line(c + Vector2(-s * 0.5, 0), c + Vector2(-s * 0.1, s * 0.45), Color("f2edda"), 2.5, true)
		game.draw_line(c + Vector2(-s * 0.1, s * 0.45), c + Vector2(s * 0.55, -s * 0.45), Color("f2edda"), 2.5, true)
	else:
		game.draw_arc(c, s - 1, 0, TAU, 20, Color("8a8467"), 2.0, true)

func draw_journal(game: Variant, area: Rect2, mobile: bool) -> void:
	game.paper_panel(area, Color("efe3c2"), 10)
	var size: int = 21 if mobile else 15
	var head: int = 24 if mobile else 17
	var col := area.size.x * 0.5
	# Shrink the text until the longest line of each column fits its width.
	var explored: int = game.map_view.percent()
	var next_goal := ""
	for i in range(MILESTONES.size()):
		if not milestones_done[i]: next_goal = "  ·  next reward at %d%%" % int(MILESTONES[i].percent); break
	var left_lines: Array[String] = []
	for step in quest_steps(game): left_lines.append(str(step.text))
	var right_lines: Array[String] = []
	for mark in LANDMARKS:
		right_lines.append((str(mark.name) + ("  (recipe: %s)" % Data.label(mark.learn) if mark.has("learn") else "")) if discovered.has(mark.id) else "???")
	while size > 11:
		var widest := 0.0
		for t in left_lines: widest = maxf(widest, game.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 1.4 + 36)
		for t in right_lines: widest = maxf(widest, game.font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * 1.4 + 30)
		var head_w: float = game.font.get_string_size("EXPLORED  %d%%%s" % [explored, next_goal], HORIZONTAL_ALIGNMENT_LEFT, -1, head).x + 30
		if widest <= col and head_w <= col: break
		size -= 1
		if head_w > col and head > size + 1: head -= 1
	var line: float = size + (12 if mobile else 9)
	var ink := Color("35483d")
	var soft := Color("657259")
	# Left: main quest.
	var x := area.position.x + 18
	var y := area.position.y + head + 14
	game.label_at(Vector2(x, y), "MAIN QUEST  ·  THE OLD BEACON", head, ink)
	y += line + 4
	for step in quest_steps(game):
		_check(game, Vector2(x + size * 0.5, y - size * 0.35), step.done, size * 0.5)
		game.label_at(Vector2(x + size * 1.4, y), step.text, size, soft if step.done else ink)
		y += line
	y += line * 0.5
	game.label_at(Vector2(x, y), "GEAR", head, ink)
	y += line
	game.draw_wrapped_text(next_gear_hint(game), Vector2(x, y), col - 36, size, 3)
	# Right: discoveries, caches, exploration.
	x = area.position.x + col + 6
	y = area.position.y + head + 14
	game.label_at(Vector2(x, y), "DISCOVERIES  %d / %d" % [discovered.size(), LANDMARKS.size()], head, ink)
	y += line + 4
	for mark in LANDMARKS:
		var known: bool = discovered.has(mark.id)
		_check(game, Vector2(x + size * 0.5, y - size * 0.35), known, size * 0.5)
		var reward := ""
		if mark.has("learn"): reward = "  (recipe: %s)" % Data.label(mark.learn)
		game.label_at(Vector2(x + size * 1.4, y), (str(mark.name) + reward) if known else "???", size, ink if known else soft)
		y += line
	y += line * 0.3
	game.label_at(Vector2(x, y), "SUPPLY CACHES  %d / %d" % [opened_count(), CACHES.size()], head, ink)
	y += line
	game.label_at(Vector2(x, y), "EXPLORED  %d%%%s" % [explored, next_goal], head, ink)
	y += line * 0.6
	var bar := Rect2(Vector2(x, y), Vector2(col - 40, 10))
	game.draw_rect(bar, Color("cbbb8f"))
	game.draw_rect(Rect2(bar.position, Vector2(bar.size.x * explored / 100.0, bar.size.y)), Color("6b8f5a"))
	for m in MILESTONES:
		var mx: float = bar.position.x + bar.size.x * float(m.percent) / 100.0
		game.draw_line(Vector2(mx, bar.position.y - 3), Vector2(mx, bar.end.y + 3), Color("a9793d"), 2.0)

func draw_banner(game: Variant, screen: Vector2) -> void:
	if banner_time <= 0.0: return
	var mobile: bool = game.mobile.enabled
	var t: float = banner_time / BANNER_TIME
	var alpha: float = clampf(minf((1.0 - t) * 8.0, t * 4.0), 0.0, 1.0)
	var title_size := 26 if mobile else 18
	var text_size := 22 if mobile else 15
	var width: float = minf(screen.x - 80, maxf(game.font.get_string_size(banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x, game.font.get_string_size(banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x) + 48)
	var top: float = (230.0 if mobile else 152.0) - (1.0 - alpha) * 12.0
	var rect := Rect2(Vector2((screen.x - width) * 0.5, top), Vector2(width, title_size + text_size + 34))
	game.paper_panel(rect, Color(0.94, 0.88, 0.69, alpha), 10)
	game.draw_rect(Rect2(rect.position + Vector2(10, 6), Vector2(rect.size.x - 20, 3)), Color(0.66, 0.47, 0.24, alpha))
	game.label_at(rect.position + Vector2(24, title_size + 12), banner_title, title_size, Color(0.42, 0.29, 0.13, alpha))
	game.label_at(rect.position + Vector2(24, title_size + text_size + 22), banner_text, text_size, Color(0.21, 0.28, 0.24, alpha))
