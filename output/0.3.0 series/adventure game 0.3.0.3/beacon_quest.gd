extends RefCounted
## v0.1.7 main quest: recover three beacon parts, repair the old beacon beside
## the northern trail, then keep its fire burning for one night watch to escape.
## v0.3.0: the parts lie in three regions: the lens in the River Valley (fish
## the glint by the Old Ferry), the gear in the Fallen Ruins' plaza, the core
## at the forest shrine. Repair needs ancient stone from the ruins.
## Art is the user-supplied painted sheet sliced without resampling; physical
## collision is each model's ground base only (assets/beacon_models.json).

const BEACON_POS := Vector2(1890, 372)
const RUNE_POS := Vector2(1100, 2050) # Fallen Ruins plaza
const SHRINE_POS := Vector2(690, 385)
const GLINT_SEED := Vector2(3060, 1300) # river edge beside the Old Ferry dock
const IGNITE_SECONDS := 60.0
const IGNITE_RADIUS := 210.0
const RUNE_HP := 6
const GLINT_CATCHES := 3
const REPAIR_COST := {"log": 4, "ancient_stone": 2}
const FUEL_COST := {"log": 3}
const PARTS := ["beacon_lens", "bronze_gear", "ember_core"]
const STATE_ART := {"broken": "beacon-broken", "repaired": "beacon-repaired", "igniting": "beacon-lit", "lit": "beacon-lit"}

var textures: Dictionary = {}
var icons: Array[Texture2D] = []
var models: Dictionary = {}
var stage := "broken"
var progress := 0.0
var rune_hp := RUNE_HP
var rune_open := false
var core_taken := false
var lens_found := false
var glint_catches := 0
var glint := Vector2.ZERO
var warned_away := false
# The Last Watch: waves of hunters converge on the fire while it charges.
const WAVES := [{"at": 5.0, "wolves": 1}, {"at": 25.0, "wolves": 2}, {"at": 45.0, "wolves": 2}]
const BEAR_AT := 30.0
var waves_sent := 0
var bear_sent := false

func load_art(game: Variant) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/beacon_models.json"))
	models = data.models
	for key in data.profiles: game.collision_profiles[key] = data.profiles[key]
	textures.clear()
	for model in models:
		for state in models[model]: textures[state] = game.load_texture("res://assets/%s.png" % state)
	icons.clear()
	for name in ["part-lens", "part-gear", "part-core"]: icons.append(game.load_texture("res://assets/%s.png" % name))

func model_textures() -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	for key in textures: result.append(textures[key])
	return result

func setup(game: Variant) -> void:
	stage = "broken"; progress = 0.0; rune_hp = RUNE_HP; rune_open = false
	core_taken = false; lens_found = false; glint_catches = 0; warned_away = false
	# The glint sits exactly on the fishable river edge beside the Old Ferry.
	glint = GLINT_SEED
	var best := INF
	for polygon in game.pond_colliders:
		for i in range(polygon.size()):
			var point: Vector2 = Geometry2D.get_closest_point_to_segment(GLINT_SEED, polygon[i], polygon[(i + 1) % polygon.size()])
			if point.distance_to(GLINT_SEED) < best: best = point.distance_to(GLINT_SEED); glint = point

func _spec(model: String, state: String, foot: Vector2) -> Dictionary:
	var info: Dictionary = models[model][state]
	return {"texture": textures[state], "foot": foot, "height": float(info.height), "profile": str(info.profile), "mirror": false}

func model_spec(kind: String) -> Dictionary:
	if textures.is_empty(): return {}
	match kind:
		"beacon": return _spec("beacon", STATE_ART[stage], BEACON_POS)
		"rune_rock": return _spec("rune_rock", "rune-rock-open" if rune_open else "rune-rock", RUNE_POS)
		"shrine": return _spec("shrine", "shrine-empty" if core_taken else "shrine-core", SHRINE_POS)
	return {}

func kinds() -> Array[String]:
	return ["beacon", "rune_rock", "shrine"]

func position(kind: String) -> Vector2:
	return {"beacon": BEACON_POS, "rune_rock": RUNE_POS, "shrine": SHRINE_POS}[kind]

func targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"pos": BEACON_POS, "kind": "beacon"}]
	if not rune_open: result.append({"pos": RUNE_POS, "kind": "rune_rock"})
	if not core_taken: result.append({"pos": SHRINE_POS, "kind": "shrine"})
	return result

func parts_found() -> int:
	return int(lens_found) + int(rune_open) + int(core_taken)

func igniting() -> bool:
	return stage == "igniting"

func objective(game: Variant) -> String:
	match stage:
		"lit": return "The beacon is lit. You are free."
		"igniting": return "Guard the beacon fire: %d s - stay close" % ceili(IGNITE_SECONDS - progress)
		"repaired": return "Light the beacon after dark: 3 logs"
	# Nearest region first: forest shrine, then the valley, then the ruins.
	if not core_taken: return "Parts %d/3 - Core: shrine west of the lake" % parts_found()
	if not lens_found: return "Parts %d/3 - Lens: fish the glint at the Old Ferry (east valley)" % parts_found()
	if not rune_open: return "Parts %d/3 - Gear: rune rock in the ruins plaza (pickaxe)" % parts_found()
	return "Repair the beacon: 4 logs + 2 ancient stone"

func prompt(kind: String) -> String:
	match kind:
		"rune_rock": return "Hold E  Break rune rock - pickaxe"
		"shrine": return "E  Take the ember core"
		"beacon":
			match stage:
				"broken": return "E  Repair beacon" if parts_found() == 3 else "E  Inspect old beacon"
				"repaired": return "E  Light beacon (3 logs)"
				"igniting": return "Keep the fire safe"
	return ""

func take_core(game: Variant) -> void:
	if core_taken: return
	core_taken = true
	game.give_item("ember_core", 1, SHRINE_POS + Vector2(0, 30))
	game.rebuild_obstacles(); game.rebuild_navigation()
	game.notify("You took the ember core. It is warm in your hands. (%d/3 parts)" % parts_found())

func rune_valid() -> bool:
	return not rune_open

func mine_hit(game: Variant, strength: int) -> void:
	if rune_open: return
	rune_hp -= maxi(1, strength)
	game.harvest_effects.append({"p": RUNE_POS, "age": 0.0, "kind": "stone"})
	if rune_hp > 0:
		game.notify("The carved stone cracks... (%d more hits)" % rune_hp)
		return
	rune_open = true
	game.give_item("bronze_gear", 1, RUNE_POS + Vector2(-14, 26))
	game.give_item("rock", 2, RUNE_POS + Vector2(18, 28))
	game.rebuild_obstacles(); game.rebuild_navigation()
	game.notify("A bronze gear was sealed inside the rune rock! (%d/3 parts)" % parts_found())

func fish_catch(game: Variant, cast_edge: Vector2) -> bool:
	# Returns true when this catch was the beacon lens instead of a fish.
	if lens_found or cast_edge.distance_to(glint) > 70.0: return false
	glint_catches += 1
	if glint_catches < GLINT_CATCHES:
		game.notify("Something heavy flashes under the glint... keep fishing here (%d/%d)." % [glint_catches, GLINT_CATCHES])
		return false
	lens_found = true
	game.give_item("beacon_lens", 1, game.player + Vector2(18, 11))
	game.notify("You fished up the beacon lens! (%d/3 parts)" % parts_found())
	return true

func interact_beacon(game: Variant) -> void:
	match stage:
		"broken":
			var missing: Array[String] = []
			for id in PARTS:
				if game.bag.count(id) < 1: missing.append(game.Data.label(id))
			if not missing.is_empty():
				game.dialog = "The old beacon\n\nMoss covers a cracked stone tower. Its bronze cage is bent and empty.\nOnce, its light could be seen far beyond the trees.\n\nIt needs three parts: a lens, a gear and an ember core.\nMissing: %s\n\nRepair also needs 4 logs and 2 iron ore." % ", ".join(missing)
				return
			if not game.bag.can_pay(REPAIR_COST):
				game.notify("Repair needs 4 logs and 2 ancient stone (ruins rubble) with the three parts.")
				return
			for id in PARTS: game.bag.remove(id, 1)
			for id in REPAIR_COST: game.bag.remove(id, int(REPAIR_COST[id]))
			game.sanitize_hotbar()
			stage = "repaired"
			game.rebuild_obstacles(); game.rebuild_navigation()
			game.notify("The beacon is repaired. Light it after sunset with 3 logs, then guard the fire.")
		"repaired":
			if game.phase not in ["dusk", "night"]:
				game.notify("Its light only carries in the dark. Return after sunset with 3 logs.")
				return
			if not game.bag.can_pay(FUEL_COST):
				game.notify("The beacon needs 3 logs to burn.")
				return
			for id in FUEL_COST: game.bag.remove(id, int(FUEL_COST[id]))
			game.sanitize_hotbar()
			stage = "igniting"; progress = 0.0; warned_away = false; waves_sent = 0; bear_sent = false
			game.notify("The beacon flares! Stay close for 60 seconds. Its light draws the predators.")
			if game.get("progression") != null:
				game.progression.show_banner("THE LAST WATCH", "Hunters converge on the fire. Keep it burning for 60 seconds!")
			print("BEACON_IGNITE night=", game.night)

func update(game: Variant, dt: float) -> void:
	if stage != "igniting" or not game.simulation_running(): return
	if game.player.distance_to(BEACON_POS) <= IGNITE_RADIUS:
		progress = minf(IGNITE_SECONDS, progress + dt)
		warned_away = false
	elif not warned_away:
		warned_away = true
		game.notify("Too far from the beacon! The fire only grows while you guard it.")
	_send_waves(game)
	if progress >= IGNITE_SECONDS:
		stage = "lit"
		print("BEACON_LIT night=", game.night)
		game.beacon_escape()

func _send_waves(game: Variant) -> void:
	if game.wildlife == null: return
	while waves_sent < WAVES.size() and progress >= float(WAVES[waves_sent].at):
		var extra: int = 1 if int(game.night) >= 4 else 0
		var n: int = game.wildlife.spawn_wave(game, BEACON_POS, "wolf", int(WAVES[waves_sent].wolves) + extra)
		print("LAST_WATCH_WAVE ", waves_sent + 1, " wolves=", n)
		if waves_sent > 0: game.notify("More wolves break from the treeline!")
		waves_sent += 1
	if not bear_sent and int(game.night) >= 3 and progress >= BEAR_AT:
		bear_sent = true
		var has_bear := false
		for a in game.wildlife.animals: if a.species == "bear": has_bear = true
		if not has_bear and game.wildlife.spawn_wave(game, BEACON_POS, "bear", 1) > 0:
			game.notify("A bear lumbers toward the fire!")

func on_dawn(game: Variant) -> void:
	if stage != "igniting": return
	stage = "repaired"; progress = 0.0
	game.notify("The fire burned out at dawn. Bring 3 logs and try again tonight.")

func glow() -> Vector3:
	# x, y, strength. The flame strengthens while it is guarded.
	if stage == "lit": return Vector3(BEACON_POS.x, BEACON_POS.y - 20, 1.0)
	if stage == "igniting": return Vector3(BEACON_POS.x, BEACON_POS.y - 20, lerpf(0.45, 1.0, progress / IGNITE_SECONDS))
	return Vector3.ZERO

func draw_ground(game: Variant) -> void:
	# A bright painted sparkle on the river marks where the lens lies.
	if lens_found: return
	var pulse: float = 0.5 + 0.5 * sin(game.elapsed * 2.4)
	var center: Vector2 = glint + Vector2(0, -18)
	game.draw_circle(center, 15.0 + pulse * 4.0, Color(1.0, 0.93, 0.62, 0.16 + pulse * 0.10))
	for k in range(3):
		var t: float = game.elapsed * 1.6 + k * 2.1
		var start: Vector2 = center + Vector2(-20.0 + k * 13.0 + cos(t) * 4.0, 6.0 - k * 5.0 + sin(t * 1.3) * 2.0)
		game.draw_line(start, start + Vector2(14, -1), Color(1.0, 0.96, 0.78, 0.45 + 0.35 * sin(t * 2.0)), 2.4, true)
	var star: float = 6.0 + pulse * 5.0
	game.draw_line(center + Vector2(-star, 0), center + Vector2(star, 0), Color(1.0, 0.98, 0.86, 0.9), 2.2, true)
	game.draw_line(center + Vector2(0, -star), center + Vector2(0, star), Color(1.0, 0.98, 0.86, 0.9), 2.2, true)
	game.draw_circle(center, 2.6, Color(1.0, 1.0, 0.92, 0.95))

func draw_overlay(game: Variant) -> void:
	# Drawn above the night fog so the guard ring and timer stay readable.
	if stage != "igniting": return
	var segments := 72
	for i in range(0, segments, 2):
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		game.draw_line(BEACON_POS + Vector2(cos(a0), sin(a0) * 0.62) * IGNITE_RADIUS, BEACON_POS + Vector2(cos(a1), sin(a1) * 0.62) * IGNITE_RADIUS, Color(1.0, 0.8, 0.45, 0.55), 2.0, true)
	var top: Vector2 = BEACON_POS + Vector2(-60, -222)
	game.draw_rect(Rect2(top - Vector2(2, 2), Vector2(124, 13)), Color(0.12, 0.16, 0.14, 0.9))
	game.draw_rect(Rect2(top, Vector2(120 * progress / IGNITE_SECONDS, 9)), Color("f0b25a"))
