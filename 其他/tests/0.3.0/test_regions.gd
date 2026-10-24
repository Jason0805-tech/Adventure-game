extends SceneTree
# v0.3.0 World Expansion: three regions, each with its own resources, danger
# and goal. Uses the real game code throughout (movement, fishing, mining,
# crafting, sanity), never shortcuts that skip the rules being tested.
var checks := 0
var failures: Array[String] = []
var g: Variant
var R: Variant
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error("FAIL " + label)
func fresh(seed: int = 164) -> void:
	if g != null: g.free()
	g = load("res://main.tscn").instantiate(); g.resource_seed = seed; root.add_child(g); g.set_process(false)
	await process_frame
	g.wildlife.animals.clear(); g.phase = "day"
	R = g.Regions
func reachable(a: Vector2, b: Vector2) -> bool:
	var from: Vector2i = g.nav_cell(a); var to: Vector2i = g.nav_cell(b)
	return from.x >= 0 and to.x >= 0 and not g.nav_grid.get_id_path(from, to).is_empty()
func stand_near(site: Vector2, max_r: float) -> Vector2:
	for r in range(0, int(max_r), 8):
		for k in range(24):
			var p: Vector2 = site + Vector2.RIGHT.rotated(TAU * k / 24.0) * r
			if g.walkable(p) and reachable(g.CAMP, p): return p
	return Vector2.INF
func walk(direction: Vector2, seconds: float) -> void:
	var steps: int = int(seconds / 0.05)
	for i in range(steps): g.move_player(direction, 0.05)
func equip(id: String) -> void:
	if g.bag.count(id) == 0: g.bag.add(id, 1)
	g.hotbar[0] = int(g.bag.slots[g.bag.first(id)].uid); g.active_hotbar = 0

func run() -> void:
	await fresh()
	# --- Layout -------------------------------------------------------------------
	check(g.WORLD == Vector2(3600, 2600), "the world grew to 3600 x 2600")
	check(R.region_at(g.CAMP) == "forest" and R.region_at(Vector2(3000, 500)) == "valley" and R.region_at(Vector2(900, 2100)) == "ruins", "three regions: woods, valley east, ruins south")
	var per := {"forest": 0, "valley": 0, "ruins": 0}
	for t in g.trees: per[R.region_at(t)] += 1
	check(per.valley >= 40 and per.ruins >= 4 and per.ruins < per.valley, "valley is wooded, the ruins are not (%s)" % str(per))
	var kinds := {}
	for it in g.items: kinds["%s/%s" % [it.kind, R.region_at(it.pos)]] = true
	check(kinds.has("reed/valley") and not kinds.has("reed/forest") and not kinds.has("reed/ruins"), "reeds grow only in the valley")
	check(not kinds.has("berry/ruins"), "no berries in the ruins: food is scarce there")
	var rubble: Array = g.ore_veins.filter(func(v): return v.get("kind", "") == "rubble")
	check(rubble.size() >= 8 and rubble.all(func(v): return R.region_at(v.p) == "ruins"), "ancient-stone rubble only in the ruins (%d)" % rubble.size())
	for it in g.items:
		if R.in_water(it.pos) or R.on_bridge(it.pos): check(false, "item %s in the river at %s" % [it.kind, str(it.pos)])
	# --- River: deep water blocks, bridge and fords cross -------------------------
	var deep := 0
	for y in range(120, 2500, 97):
		if R.crossing_at(y) != "": continue
		if not g.static_walkable(Vector2(R.river_x(y), y)): deep += 1
	check(deep >= 20, "deep water blocks walking along the whole river (%d)" % deep)
	g.player = Vector2(R.river_x(756) - 160, 756)
	check(g.walkable(g.player), "the road reaches the west end of the bridge")
	walk(Vector2.RIGHT, 4.0)
	check(g.player.x > R.river_x(756) + R.RIVER_HALF + 30, "walking east over the bridge reaches the far bank (x %.0f)" % g.player.x)
	g.player = Vector2(R.river_x(1300) - 150, 1300)
	walk(Vector2.RIGHT, 4.0)
	check(g.player.x < R.river_x(1300) - R.RIVER_HALF + 4, "away from the crossings the river stops the player (x %.0f)" % g.player.x)
	for ford in ["north_ford", "south_ford"]:
		var y: float = g.Regions.ford_rect(ford).get_center().y
		g.player = Vector2(R.river_x(y) - 150, y)
		walk(Vector2.RIGHT, 8.0)
		check(g.player.x > R.river_x(y) + R.RIVER_HALF + 20, "%s can be waded across" % ford)
	# Wading is slow and noisy.
	var y0: float = R.ford_rect("north_ford").get_center().y
	g.player = Vector2(R.river_x(y0) - 60, y0)
	var start: Vector2 = g.player
	walk(Vector2.RIGHT, 0.5)
	var ford_speed: float = g.player.distance_to(start) / 0.5
	g.player = Vector2(2260, 756); start = g.player # open valley road
	walk(Vector2.RIGHT, 0.5)
	var land_speed: float = g.player.distance_to(start) / 0.5
	check(absf(ford_speed / land_speed - R.FORD_SPEED) < 0.08, "wading moves at %.0f%% speed (%.0f vs %.0f)" % [100.0 * ford_speed / land_speed, ford_speed, land_speed])
	g.phase = "night"; g.wildlife.period = "night"; g.wildlife.animals.clear(); g.wildlife.noises.clear()
	g.player = Vector2(R.river_x(y0), y0)
	var listener: Dictionary = {}
	for k in range(60):
		var q: Vector2 = g.player + Vector2.RIGHT.rotated(TAU * k / 60.0) * 250.0
		if g.wildlife._walkable(g, {"species": "wolf", "facing": Vector2.DOWN, "uid": -3}, q):
			listener = g.wildlife._register_animal(g, "wolf", q, Vector2.DOWN); listener.age = 30.0; listener.state = "idle"; break
	g.moving = true
	g.region_world.splash_in = 0.0
	g.region_world.update(g, 0.1)
	check(not listener.is_empty() and listener.state == "investigate", "splashing through a ford draws a nearby wolf")
	g.phase = "day"; g.wildlife.period = "day"; g.wildlife.animals.clear(); g.moving = false
	# --- Fishing: river trout, the lens at the Old Ferry ---------------------------
	check(R.region_at(g.beacon.glint) == "valley" and g.beacon.glint.distance_to(R.OLD_FERRY) < 220, "the lens glints in the river by the Old Ferry (%s)" % str(g.beacon.glint))
	var cast := stand_near(g.beacon.glint, 80.0)
	check(cast != Vector2.INF, "a reachable fishing spot beside the glint")
	g.player = Vector2(R.river_x(1800) + R.RIVER_HALF + 30, 1800)
	if not g.walkable(g.player): g.release_player()
	equip("fishing_rod")
	var water: Dictionary = g.nearest_water()
	check(not water.is_empty() and g.region_world.is_river(int(water.index), g), "the river is fishable")
	if not water.is_empty():
		g.action = {"target": water, "uid": g.hotbar[0], "id": "fishing_rod", "elapsed": 0.0, "duration": 2.0, "hit": false}
		g.commit_action()
		check(g.bag.count("trout") == 1, "river fishing lands a trout")
		g.fullness = 50
		equip("trout"); g.use_selected()
		check(g.fullness == 90, "a trout restores 40 fullness (now %d)" % g.fullness)
	g.player = cast
	var glint_water: Dictionary = g.nearest_water()
	for i in range(g.beacon.GLINT_CATCHES):
		if g.beacon.lens_found: break
		g.beacon.fish_catch(g, g.beacon.glint)
	check(g.beacon.lens_found, "fishing at the glint brings up the beacon lens")
	# --- Rubble, ancient stone and the beacon repair --------------------------------
	equip("pickaxe")
	var bronze := 0
	for vein in rubble:
		var index: int = g.ore_veins.find(vein)
		var spot := stand_near(vein.p, 70.0)
		check(spot != Vector2.INF, "rubble at %s can be reached" % str(vein.p))
		if spot == Vector2.INF: continue
		g.player = spot
		var stone_before: int = g.bag.count("ancient_stone")
		var bronze_before: int = g.bag.count("bronze_scrap")
		vein.hp = 1
		g.action = {"target": {"kind": "ore", "pos": vein.p, "index": index}, "uid": g.hotbar[0], "id": "pickaxe", "elapsed": 0.0, "duration": 0.8, "hit": false}
		g.commit_action()
		check(vein.depleted and g.bag.count("ancient_stone") + g.items.filter(func(it): return it.kind == "ancient_stone" and it.get("dropped", false) and not it.taken).size() * 3 >= stone_before + 3, "breaking rubble gives ancient stone")
		check(g.static_walkable(g.player), "the player stands free after breaking rubble")
		if g.bag.count("bronze_scrap") > bronze_before: bronze += 1
		equip("pickaxe")
	check(bronze >= 2 and bronze < rubble.size(), "some rubble piles hold bronze scrap (%d/%d)" % [bronze, rubble.size()])
	check(g.beacon.REPAIR_COST.has("ancient_stone") and not g.beacon.REPAIR_COST.has("ore"), "the beacon repair needs ancient stone, not iron ore")
	# --- Haunting -----------------------------------------------------------------------
	await fresh()
	var drain := func(p: Vector2, seconds: float) -> float:
		g.player = p
		if not g.walkable(g.player): g.release_player()
		g.sanity = 90.0
		for i in range(int(seconds / 0.1)): g.survival.update(g, 0.1)
		return 90.0 - g.sanity
	var woods: float = drain.call(Vector2(900, 900), 10.0)
	var edge: float = drain.call(Vector2(300, 2400), 10.0)
	var deep_ruins: float = drain.call(R.PLAZA + Vector2(0, 160), 10.0)
	check(woods < 0.01, "the woods do not drain sanity by day (%.2f)" % woods)
	check(edge > 1.5 and deep_ruins > edge * 1.4, "the ruins drain sanity by day, the deep ruins more (%.2f / %.2f per 10 s)" % [edge, deep_ruins])
	g.bag.add("rune_charm", 1)
	var charmed: float = drain.call(R.PLAZA + Vector2(0, 160), 10.0)
	check(charmed < deep_ruins * 0.5, "a rune charm calms the whispers (%.2f vs %.2f)" % [charmed, deep_ruins])
	g.bag.remove("rune_charm", 1)
	# Daytime shadows in the deep ruins only.
	g.player = R.PLAZA + Vector2(0, 160)
	if not g.walkable(g.player): g.release_player()
	g.sanity = 40.0; g.survival.shadow_cooldown = 0; g.survival.shadow_retry = 0; g.torch_lit = false
	g.survival.update(g, 0.05)
	check(g.wildlife.has_shadow(), "a shadow can take shape in the deep ruins by day")
	g.wildlife.dismiss_shadow(); g.bag.add("rune_charm", 1); g.survival.shadow_cooldown = 0; g.survival.shadow_retry = 0
	g.survival.update(g, 0.05)
	check(not g.wildlife.has_shadow(), "the rune charm keeps daytime shadows away")
	g.bag.remove("rune_charm", 1); g.wildlife.dismiss_shadow()
	g.player = Vector2(900, 900); g.sanity = 40.0; g.survival.shadow_cooldown = 0; g.survival.shadow_retry = 0
	g.survival.update(g, 0.05)
	check(not g.wildlife.has_shadow(), "no daytime shadows in the woods")
	# --- Region banners -------------------------------------------------------------------
	g.progression.banner_queue.clear(); g.progression.banner_title = ""; g.progression.banner_time = 0.0
	g.region_world.visited = {"forest": true}; g.region_world.region = "forest"
	g.player = Vector2(2600, 900); g.region_world.update(g, 0.1)
	check(g.progression.banner_title == "ENTERING  RIVER VALLEY", "entering the valley announces it (%s)" % g.progression.banner_title)
	g.player = Vector2(900, 900); g.region_world.update(g, 0.1)
	g.progression.banner_title = ""; g.progression.banner_queue.clear(); g.progression.banner_time = 0.0
	g.player = Vector2(2600, 900); g.region_world.update(g, 0.1)
	check(g.progression.banner_title == "" and g.progression.banner_queue.is_empty(), "the second visit is not announced again")
	# --- Reeds -> fibers, rune charm recipe -----------------------------------------------------
	var reed := -1
	for i in range(g.items.size()):
		if g.items[i].kind == "reed" and not g.items[i].taken: reed = i; break
	g.player = g.items[reed].pos + Vector2(0, 24)
	if not g.walkable(g.player): g.release_player()
	g.collect_item(reed)
	check(g.bag.count("reed") >= 1, "reeds can be gathered by hand")
	g.bag.add("reed", 5)
	var rope_recipe := -1; var charm_recipe := -1
	for i in range(g.Data.RECIPES.size()):
		if g.Data.RECIPES[i].id == "rope": rope_recipe = i
		if g.Data.RECIPES[i].id == "rune_charm": charm_recipe = i
	var ropes: int = g.bag.count("rope")
	g.crafting = true; g.crafting_station = -1
	g.craft_recipe(rope_recipe)
	check(g.bag.count("rope") == ropes, "reed fibers must be learned first")
	g.progression.learned["rope"] = true
	var reeds: int = g.bag.count("reed")
	g.craft_recipe(rope_recipe)
	check(g.bag.count("rope") == ropes + 2 and g.bag.count("reed") == reeds - 3, "3 reeds twist into 2 fibers")
	check(g.progression.learn_place("rope") == "Old Ferry" and g.progression.learn_place("rune_charm") == "Sunken Well", "the valley teaches fibers, the ruins teach the charm")
	g.progression.learned["rune_charm"] = true
	g.bag.add("ancient_stone", 2); g.bag.add("bronze_scrap", 1)
	g.player = stand_near(g.workbenches[0].p, 80.0); g.crafting_station = 1
	g.craft_recipe(charm_recipe)
	check(g.bag.count("rune_charm") == 1, "a rune charm is crafted at a workbench")
	g.crafting = false
	# --- Everything new can be reached on foot ----------------------------------------------------
	for mark in g.progression.LANDMARKS:
		check(stand_near(mark.pos, float(mark.radius) * 0.8) != Vector2.INF, "%s can be reached from camp" % mark.name)
	for cache in g.progression.CACHES:
		check(stand_near(cache, 90.0) != Vector2.INF, "cache at %s can be reached" % str(cache))
	check(stand_near(g.beacon.RUNE_POS, 90.0) != Vector2.INF, "the rune rock in the plaza can be reached")
	# Roads and the bridge deck stay clear of scenery.
	var blocked_road := 0
	var blockers: Array = []
	for path in R.PATHS:
		var pts: Array = path.points
		for i in range(pts.size() - 1):
			for t in range(0, 20):
				var p: Vector2 = pts[i].lerp(pts[i + 1], t / 20.0)
				if R.FOREST.has_point(p) or R.in_water(p) and not R.crossing_at(p.y).ends_with("ford") and not R.on_bridge(p): continue
				# Roads meet at the rune rock in the open paved plaza; walk around it.
				if p.distance_to(R.PLAZA) < 90.0: continue
				if not g.static_walkable(p):
					blocked_road += 1
					var bounds: Rect2 = g.Geometry.polygon_bounds(g.feet_polygon(p))
					for body in g.bodies_in(bounds):
						if g.body_active(body) and g.Geometry.polygons_overlap(g.feet_polygon(p), body.polygon) and blockers.size() < 12:
							blockers.append("%s@%s" % [str(body.id), str(p.round())])
	check(blocked_road == 0, "nothing blocks the new roads (%d blocked points) %s" % [blocked_road, str(blockers)])
	# --- Map --------------------------------------------------------------------------------------------
	check(g.ground_layer.map_texture != null and g.ground_layer.map_texture.get_width() * g.ground_layer.MASK_CELL >= g.WORLD.x, "the world map shows all three regions")
	# --- Frame cost in each region -----------------------------------------------------------------------
	var costs := {}
	for spot in [Vector2(900, 900), Vector2(2650, 900), R.PLAZA + Vector2(0, 160)]:
		g.player = spot
		if not g.walkable(g.player): g.release_player()
		g.camera = g.player - Vector2(640, 480)
		var t0 := Time.get_ticks_usec()
		for i in range(10): g.paint_entries(true)
		costs[R.region_at(spot)] = snappedf((Time.get_ticks_usec() - t0) / 10000.0, 0.01)
	print("PAINT_MS ", JSON.stringify(costs))
	check(costs.values().all(func(ms): return ms < 25.0), "drawing scenery stays cheap in every region")
	print("REGIONS_RESULTS ", JSON.stringify({"checks": checks, "failures": failures, "passed": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
