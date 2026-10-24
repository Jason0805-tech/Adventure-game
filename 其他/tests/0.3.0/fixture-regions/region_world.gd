extends RefCounted
## v0.3.0 World Expansion: what makes each region different to play.
##   River Valley: deep river (fish it for trout), bridge and two slow, noisy
##   fords, reeds on the banks, bears favour the water.
##   Fallen Ruins: haunted (sanity drains by day, faster in the deep ruins
##   where shadows walk in daylight), ancient-stone rubble, little food.
## Layout comes from regions.gd. Scenery reuses the existing systems: ruins and
## valley objects are props, rubble piles are ore veins with kind "rubble",
## reeds are ground items and valley trees are ordinary trees.

const Regions = preload("res://regions.gd")
const HAUNT_DAY := 0.22 # sanity per second in the ruins by day
const HAUNT_DEEP := 0.40 # ... in the deep ruins
const HAUNT_NIGHT_MULT := 1.5
const CHARM_MULT := 0.4
const TORCH_HAUNT_MULT := 0.6
const DEEP_SHADOW_SANITY := 50.0
const SPLASH_RADIUS := 330.0
const SPLASH_EVERY := 0.9
const TROUT_FULLNESS := 40
const TROUT_SANITY := 6.0
# Placeholder art until the painted region sheets arrive (assets/region/*.png).
# Each feature: art key -> [texture source, collision profile, height].
const FEATURE_ART := {
	"column": "res://assets/region/ruin-column.png",
	"fallen_column": "res://assets/region/ruin-fallen-column.png",
	"wall": "res://assets/region/ruin-wall.png",
	"statue": "res://assets/region/ruin-statue.png",
	"boulder": "res://assets/region/valley-boulder.png",
	"driftwood": "res://assets/region/valley-driftwood.png",
	"ferry_post": "res://assets/region/valley-ferry-post.png",
	"well": "res://assets/region/ruin-well.png",
	"arch": "",
}
const HEIGHT := {"column": 100.0, "fallen_column": 40.0, "wall": 58.0, "statue": 104.0, "boulder": 46.0, "driftwood": 34.0, "ferry_post": 62.0, "well": 54.0, "arch": 132.0}

var visited: Dictionary = {}
var region := "forest"
var splash_in := 0.0
var wading := false
var textures: Dictionary = {}
var profiles: Dictionary = {}
var rng := RandomNumberGenerator.new()

# --- Art -------------------------------------------------------------------------
var game_ref: Variant

func load_art(game: Variant) -> void:
	game_ref = game
	textures.clear(); profiles.clear()
	var beacon_tex: Dictionary = game.beacon.textures
	var beacon_models: Dictionary = game.beacon.models
	for key in FEATURE_ART:
		var path: String = FEATURE_ART[key]
		if not path.is_empty() and FileAccess.file_exists(path) and game.collision_profiles.has("region_" + key):
			textures[key] = game.load_texture(path); profiles[key] = "region_" + key
			continue
		# Placeholders: existing painted objects with their measured footprints.
		match key:
			"column", "statue": textures[key] = beacon_tex["rune-rock"]; profiles[key] = str(beacon_models.rune_rock["rune-rock"].profile)
			"fallen_column", "wall", "well": textures[key] = beacon_tex["shrine-empty"]; profiles[key] = str(beacon_models.shrine["shrine-empty"].profile)
			"boulder": textures[key] = game.harvest_art[3]; profiles[key] = "resource_rock_0"
			"driftwood": textures[key] = game.prop_art[1]; profiles[key] = "prop_1"
			"ferry_post": textures[key] = game.prop_art[3]; profiles[key] = "prop_3"
			"arch": textures[key] = game.art[5]; profiles[key] = "gate"

func feature_spec(prop: Dictionary) -> Dictionary:
	var key: String = str(prop.art)
	return {"texture": textures[key], "foot": prop.p, "height": float(prop.height), "profile": profiles[key], "mirror": bool(prop.get("mirror", false)), "tint": prop.get("tint", Color.WHITE)}

func textures_for_anchors() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for key in textures: if not out.has(textures[key]): out.append(textures[key])
	return out

# --- Layout ------------------------------------------------------------------------
func clear_spot(game: Variant, p: Vector2, keep: float) -> bool:
	if not Rect2(Vector2(90, 110), Regions.WORLD - Vector2(180, 220)).has_point(p): return false
	if Regions.FOREST.has_point(p): return false
	if absf(Regions.river_offset(p)) < Regions.RIVER_HALF + 40.0 and Regions.region_at(p) == "valley": return false
	if Regions.on_path(p, 36.0): return false
	for site in [Regions.PLAZA, Regions.FALLEN_GATE, Regions.SUNKEN_WELL, Regions.OLD_FERRY, Regions.WILLOW_BEND, Regions.DRIFTWOOD_SHORE]:
		if p.distance_to(site) < (Regions.PLAZA_RADIUS if site == Regions.PLAZA else 120.0): return false
	if game.quest_site_near(p, 130.0): return false
	for t in game.trees: if t.distance_to(p) < keep: return false
	for s in game.shrubs: if s.distance_to(p) < keep * 0.6: return false
	for prop in game.props: if prop.p.distance_to(p) < keep: return false
	for vein in game.ore_veins: if vein.p.distance_to(p) < keep: return false
	return true

func add_prop(game: Variant, art: String, p: Vector2, mirror: bool = false, tint: Color = Color.WHITE) -> void:
	game.props.append({"p": p, "art": art, "height": HEIGHT[art] * rng.randf_range(0.92, 1.08), "mirror": mirror, "tint": tint, "region": Regions.region_at(p)})

func build_layout(game: Variant) -> void:
	# Called from build_world after the forest is laid out. Deterministic.
	rng.seed = 30300
	visited = {"forest": true}; region = "forest"
	# Ruins: the gate where the south road enters, a ring of ruins around the
	# plaza, scattered walls and columns, the sunken well.
	# The old arch stands beside the road (its pillars must not plug the way).
	add_prop(game, "arch", Regions.FALLEN_GATE + Vector2(-150, 10))
	add_prop(game, "well", Regions.SUNKEN_WELL + Vector2(0, -40))
	var ring := ["column", "statue", "wall", "column", "fallen_column", "column", "statue", "wall", "column", "fallen_column"]
	for i in range(ring.size()):
		var a: float = TAU * i / ring.size() + 0.3
		var p: Vector2 = Regions.PLAZA + Vector2(cos(a), sin(a) * 0.82) * 305.0
		if Regions.on_path(p, 30.0): p += Vector2(cos(a), sin(a)) * 70.0
		if not Regions.on_path(p, 24.0): add_prop(game, ring[i], p, i % 2 == 1)
	# A few weathered trees and bushes at the ruins' edges: wood is scarce here.
	for attempt in range(600):
		if game.trees.filter(func(t): return Regions.region_at(t) == "ruins").size() >= 9: break
		var p := Vector2(rng.randf_range(120, 2100), rng.randf_range(1580, 2480))
		if p.distance_to(Regions.PLAZA) < 700.0 or not clear_spot(game, p, 170.0): continue
		game.tree_styles[p] = 1 if rng.randf() < 0.6 else 4
		game.trees.append(p)
	var kinds := ["wall", "column", "fallen_column", "wall", "statue", "column"]
	var placed := 0
	for attempt in range(900):
		if placed >= 30: break
		var p := Vector2(rng.randf_range(120, 2100), rng.randf_range(1600, 2490))
		if not clear_spot(game, p, 150.0): continue
		add_prop(game, kinds[placed % kinds.size()], p, rng.randf() < 0.5)
		placed += 1
	for attempt in range(300):
		if game.shrubs.filter(func(s): return Regions.region_at(s) == "ruins").size() >= 12: break
		var p := Vector2(rng.randf_range(120, 2100), rng.randf_range(1580, 2480))
		if clear_spot(game, p, 110.0): game.shrubs.append(p)
	# Valley: willows on the banks, mixed woods on both sides, boulders and
	# driftwood on the shore, the old ferry post.
	add_prop(game, "ferry_post", Regions.OLD_FERRY + Vector2(-70, 40))
	var willows := 0
	for attempt in range(600):
		if willows >= 12: break
		var y := rng.randf_range(120, 2480)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var p := Vector2(Regions.river_x(y) + side * (Regions.RIVER_HALF + Regions.BANK + rng.randf_range(35, 90)), y)
		if not clear_spot(game, p, 190.0): continue
		game.tree_styles[p] = 2
		game.trees.append(p); willows += 1
	var woods := 0
	for attempt in range(1500):
		if woods >= 46: break
		var p := Vector2(rng.randf_range(2290, 3510), rng.randf_range(110, 2490))
		if absf(Regions.river_offset(p)) < Regions.RIVER_HALF + Regions.BANK + 50.0: continue
		if not clear_spot(game, p, 165.0): continue
		var usage := [0, 0, 0, 0, 0, 0]
		for t in game.trees:
			if t.distance_to(p) < 280 and game.tree_styles.has(t): usage[int(game.tree_styles[t])] += 1
		var variant := woods % 6
		for k in range(6):
			if usage[(woods + k) % 6] < usage[variant]: variant = (woods + k) % 6
		game.tree_styles[p] = variant
		game.trees.append(p); woods += 1
		if woods % 3 == 0 and clear_spot(game, p + Vector2(65, 24), 60.0): game.shrubs.append(p + Vector2(65, 24))
	for n in range(22):
		for attempt in range(80):
			var y := rng.randf_range(120, 2480)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var shore: bool = n < 15
			var off: float = Regions.RIVER_HALF + rng.randf_range(18, 58) if shore else rng.randf_range(260, 600)
			var p := Vector2(Regions.river_x(y) + side * off, y)
			if Regions.crossing_at(y) != "" or absf(y - Regions.OLD_FERRY.y) < 90: continue
			if shore and absf(Regions.river_offset(p)) < Regions.RIVER_HALF + 14.0: continue
			if not Regions.VALLEY.grow(-60).has_point(p): continue
			if Regions.on_path(p, 30.0): continue
			var crowded := false
			for prop in game.props: if prop.p.distance_to(p) < 120: crowded = true
			for t in game.trees: if t.distance_to(p) < 110: crowded = true
			if crowded: continue
			add_prop(game, "boulder" if n % 3 != 2 else "driftwood", p, rng.randf() < 0.5, Color(0.86, 0.9, 0.92) if n % 3 != 2 else Color.WHITE)
			break

func build_rubble(game: Variant) -> void:
	# Ancient-stone rubble: ore veins of kind "rubble", mostly near the plaza.
	# Runs after the forest ore veins are placed (that step resets the list).
	var r := RandomNumberGenerator.new()
	r.seed = 30311
	var rubble := 0
	for attempt in range(900):
		if rubble >= 10: break
		var p: Vector2
		if rubble < 7: p = Regions.PLAZA + Vector2.from_angle(r.randf() * TAU) * r.randf_range(340, 660)
		else: p = Vector2(r.randf_range(160, 2080), r.randf_range(1620, 2460))
		if not clear_spot(game, p, 110.0) or Regions.region_at(p) != "ruins": continue
		if not game.static_walkable(p) or not game.static_walkable(p + Vector2(0, 38)): continue
		game.ore_veins.append({"p": p, "hp": 3, "depleted": false, "variant": rubble % 3, "kind": "rubble"})
		rubble += 1

func rubble_spec(vein: Dictionary) -> Dictionary:
	if textures.has("rubble") and textures.has("rubble_mined"):
		var key: String = "rubble_mined" if vein.depleted else "rubble"
		return {"texture": textures[key], "foot": vein.p, "height": 34.0 if vein.depleted else 50.0, "profile": profiles["rubble"], "mirror": int(vein.p.x) % 2 == 0}
	# Placeholder: the grey ore outcrop, greyed further so it reads as cut stone.
	var variant: int = int(vein.variant) % 3
	return {"texture": game_ref.utility_props[3 + variant], "foot": vein.p, "height": 34.0 if vein.depleted else 50.0, "profile": "ore_%d" % variant, "mirror": false, "tint": Color(0.82, 0.78, 0.72)}

func break_rubble(game: Variant, vein: Dictionary, at: Vector2) -> void:
	game.give_item("ancient_stone", 3, at + Vector2(-10, 9))
	# Bronze turns up in roughly every second pile (fixed per pile).
	var bronze: bool = (int(vein.p.x) + int(vein.p.y)) % 2 == 0
	if bronze: game.give_item("bronze_scrap", 1, at + Vector2(15, 12))
	game.notify("Broke the rubble: 3 ancient stone" + (" + bronze scrap." if bronze else "."))

func water_bodies() -> Array[PackedVector2Array]:
	return Regions.river_quads()

# --- Resources -----------------------------------------------------------------------
func resource_candidate(game: Variant, rng_in: RandomNumberGenerator, kind: String, zone: Rect2, zone_trees: Array) -> Vector2:
	var reg := Regions.region_at(zone.get_center())
	if kind == "reed":
		var y := rng_in.randf_range(zone.position.y, zone.end.y)
		var side := -1.0 if rng_in.randf() < 0.5 else 1.0
		return Vector2(Regions.river_x(y) + side * (Regions.RIVER_HALF + rng_in.randf_range(12, 120)), y)
	if kind in ["branch", "berry"]:
		if zone_trees.is_empty(): return Vector2.INF
		var tree: Vector2 = zone_trees[rng_in.randi_range(0, zone_trees.size() - 1)]
		return tree + Vector2.from_angle(rng_in.randf() * TAU) * rng_in.randf_range(47, 116)
	if kind == "rock" and reg == "valley" and rng_in.randf() < 0.65:
		var y2 := rng_in.randf_range(zone.position.y, zone.end.y)
		return Vector2(Regions.river_x(y2) + (-1.0 if rng_in.randf() < 0.5 else 1.0) * (Regions.RIVER_HALF + rng_in.randf_range(20, 160)), y2)
	if kind == "rock" and reg == "ruins" and rng_in.randf() < 0.6:
		return Regions.PLAZA + Vector2.from_angle(rng_in.randf() * TAU) * rng_in.randf_range(260, 700)
	var p := zone.position + Vector2(rng_in.randf(), rng_in.randf()) * zone.size
	if kind == "rope" and (game.tree_distance(p) < 92 or game.forest_density(p) >= 3): return Vector2.INF
	return p

# --- Per-frame rules ---------------------------------------------------------------------
func update(game: Variant, dt: float) -> void:
	var now := Regions.region_at(game.player)
	if now != region:
		region = now
		if not visited.has(now):
			visited[now] = true
			game.progression.show_banner("ENTERING  " + str(Regions.INFO[now].name).to_upper(), str(Regions.INFO[now].text))
	wading = Regions.in_ford(game.player)
	if wading and game.moving:
		splash_in -= dt
		if splash_in <= 0.0:
			splash_in = SPLASH_EVERY
			if game.wildlife != null: game.wildlife.make_noise(game, game.player, SPLASH_RADIUS, "splash")
	else:
		splash_in = minf(splash_in, 0.2)

func speed_scale(game: Variant) -> float:
	return Regions.FORD_SPEED if Regions.in_ford(game.player) else 1.0

func haunt_rate(game: Variant) -> float:
	# Sanity lost per second to the ruins themselves.
	if Regions.region_at(game.player) != "ruins": return 0.0
	var rate: float = HAUNT_DEEP if Regions.deep_ruins(game.player) else HAUNT_DAY
	if game.phase == "night": rate *= HAUNT_NIGHT_MULT
	if game.bag.count("rune_charm") > 0: rate *= CHARM_MULT
	if game.torch_lit and game.torch_fuel > 0: rate *= TORCH_HAUNT_MULT
	return rate

func daylight_shadows(game: Variant) -> bool:
	# Deep in the ruins a shadow can take shape by day once the mind frays.
	return Regions.deep_ruins(game.player) and game.bag.count("rune_charm") == 0 and not (game.torch_lit and game.torch_fuel > 0)

func is_river(index: int, game: Variant) -> bool:
	return index >= game.pools.size()

# --- Drawing ------------------------------------------------------------------------------
func draw_ground(game: Variant) -> void:
	# Bridge deck and ferry dock are painted ground, drawn over the water.
	var view := Rect2(game.camera, game.get_viewport_rect().size).grow(200)
	var deck: Rect2 = Regions.bridge_rect()
	if view.intersects(deck): _draw_planks(game, deck, true)
	var dock := Rect2(Vector2(Regions.river_x(Regions.OLD_FERRY.y) + Regions.RIVER_HALF - 70.0, Regions.OLD_FERRY.y - 34.0), Vector2(92, 68))
	if view.intersects(dock): _draw_planks(game, dock, false)
	for name in ["north_ford", "south_ford"]:
		var ford: Rect2 = Regions.ford_rect(name)
		if not view.intersects(ford): continue
		for k in range(7):
			var y: float = ford.position.y + 14.0 + k * (ford.size.y - 28.0) / 6.0
			var x: float = Regions.river_x(y) - Regions.RIVER_HALF + 18.0 + fposmod(game.elapsed * 22.0 + k * 37.0, Regions.RIVER_HALF * 2.0 - 60.0)
			game.draw_line(Vector2(x, y), Vector2(x + 22, y + 1), Color(0.93, 0.98, 0.92, 0.35), 2.0, true)
	for key in ["valley", "ruins"]:
		var at: Vector2 = Vector2(2470, 130) if key == "valley" else Vector2(1240, 1600)
		if view.has_point(at): game.label_at(at, str(Regions.INFO[key].name).to_upper(), 19, Color("304c3c"))
	if view.has_point(Regions.OLD_FERRY + Vector2(-70, -70)): game.label_at(Regions.OLD_FERRY + Vector2(-90, -90), "OLD FERRY", 17, Color("304c3c"))

func _draw_planks(game: Variant, rect: Rect2, rails: bool) -> void:
	game.draw_rect(rect.grow(3), Color(0.29, 0.21, 0.14, 0.55))
	var plank := 14.0
	var x := rect.position.x
	var i := 0
	while x < rect.end.x:
		var w := minf(plank, rect.end.x - x)
		var shade := 0.92 + 0.08 * float((i * 7) % 3) / 2.0
		game.draw_rect(Rect2(Vector2(x, rect.position.y), Vector2(w - 1.5, rect.size.y)), Color(0.62 * shade, 0.47 * shade, 0.31 * shade))
		x += plank; i += 1
	if rails:
		for y in [rect.position.y + 3.0, rect.end.y - 7.0]:
			game.draw_rect(Rect2(Vector2(rect.position.x - 4, y), Vector2(rect.size.x + 8, 5)), Color(0.42, 0.3, 0.2))
