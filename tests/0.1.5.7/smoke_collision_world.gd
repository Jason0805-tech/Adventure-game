extends SceneTree

const Geometry = preload("res://world_geometry.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL collision world: " + message)

func _initialize() -> void:
	call_deferred("_run")

func interior_point(polygon: PackedVector2Array) -> Vector2:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	var best_area: float = -1.0
	var best: Vector2 = Vector2.INF
	for index in range(0, triangles.size(), 3):
		var a: Vector2 = polygon[triangles[index]]
		var b: Vector2 = polygon[triangles[index + 1]]
		var c: Vector2 = polygon[triangles[index + 2]]
		var area: float = absf((b - a).cross(c - a))
		if area > best_area:
			best_area = area
			best = (a + b + c) / 3.0
	return best

func polygon_area(polygon: PackedVector2Array) -> float:
	var area: float = 0.0
	for index in range(polygon.size()):
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(area) * 0.5

func model_area(game: Variant, spec: Dictionary) -> float:
	var area: float = 0.0
	for polygon in game.model_polygons(spec):
		area += polygon_area(polygon)
	return area

func _run() -> void:
	var game: Variant = load("res://main.tscn").instantiate()
	game.resource_seed = 157
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	check(game.solid_bodies.size() > 100, "full world has detailed solid instances")
	var feet: PackedVector2Array = game.feet_polygon(Vector2(1100, 750))
	check(feet.size() >= 16, "player and NPC use smooth capsule feet")
	var feet_bounds: Rect2 = Geometry.polygon_bounds(feet)
	check(feet_bounds.is_equal_approx(Rect2(Vector2(1086, 742), Vector2(28, 14))), "feet bounds match actual ground contact")
	check(not Geometry.point_in_polygon_or_boundary(feet_bounds.position, feet), "capsule corners are passable rather than rectangular")
	var profile_count: int = 0
	for key in game.collision_profiles:
		var profile: Dictionary = game.collision_profiles[key]
		for contour in profile.polygons:
			check(contour.size() >= 8, "profile has detailed contour: " + key)
			var polygon := PackedVector2Array()
			for pair in contour: polygon.append(Vector2(pair[0], pair[1]))
			check(not Geometry2D.triangulate_polygon(polygon).is_empty(), "profile is a simple usable polygon: " + key)
		profile_count += 1
	print("PASS world profiles checked: ", profile_count)
	var bench_origin: Vector2 = interior_point(game.model_polygons(game.model_spec("bench", Vector2.ZERO))[0])
	var body_count: int = 0
	var kinds: Dictionary = {}
	for body in game.solid_bodies:
		var polygon: PackedVector2Array = body.polygon
		var inside: Vector2 = interior_point(polygon)
		check(polygon.size() >= 8, "actual body contour has detailed nodes: " + str(body.id))
		check(inside.is_finite() and Geometry.point_in_polygon_or_boundary(inside, polygon), "body has verified interior: " + str(body.id))
		check(body.bounds.is_equal_approx(Geometry.polygon_bounds(polygon)), "body AABB matches contour: " + str(body.id))
		if game.body_active(body):
			check(not game.static_walkable(inside), "actual body blocks capsule feet: " + str(body.id))
			check(not game.npc_walkable(inside, "Ash"), "actual body blocks NPC feet: " + str(body.id))
			check(not game.can_place_bench(inside - bench_origin), "workbench cannot overlap actual body: " + str(body.id))
		if body.kind == "water":
			check(polygon.size() >= 40, "pond follows painted shoreline")
			check(polygon_area(polygon) < body.bounds.get_area() * 0.9, "pond has rounded irregular shore rather than rectangle")
		else:
			var spec: Dictionary = game.model_spec(body.kind, body.p, int(body.index))
			var contours: Array[PackedVector2Array] = game.model_polygons(spec)
			var front: float = -INF
			for contour in contours: front = maxf(front, Geometry.polygon_bounds(contour).end.y)
			check(absf(float(body.depth) - game.model_depth(spec)) < 0.001, "body and draw order use same depth: " + str(body.id))
			check(absf(float(body.depth) - front) < 0.3, "draw depth follows contour front: " + str(body.id))
			var flipped: Dictionary = spec.duplicate()
			flipped.mirror = not spec.mirror
			var reflected: Array[PackedVector2Array] = game.model_polygons(flipped)
			check(reflected.size() == contours.size(), "mirror preserves contour parts: " + str(body.id))
			for contour_index in range(contours.size()):
				var first: PackedVector2Array = contours[contour_index]
				var second: PackedVector2Array = reflected[contour_index]
				for point_index in range(first.size()):
					var expected := Vector2(float(spec.foot.x) * 2.0 - first[point_index].x, first[point_index].y)
					check(second[point_index].is_equal_approx(expected), "mirror matches sprite root mapping: " + str(body.id))
		kinds[body.kind] = true
		body_count += 1
	print("PASS actual world body instances checked: ", body_count, " kinds=", kinds.keys())
	var removed_resource: bool = false
	for body in game.solid_bodies:
		if body.kind == "resource":
			var index: int = int(body.index)
			game.items[index].taken = true
			check(not game.body_active(body), "taken material immediately releases collision without stale cache")
			game.items[index].taken = false
			removed_resource = true
			break
	check(removed_resource, "resource activation test exercised")
	for p in game.trees:
		var stable: Dictionary = game.model_spec("tree", p)
		for shake in [0.0, 0.1, 0.25, 0.8]:
			game.tree_states[p].shake = shake
			var sample: Dictionary = game.model_spec("tree", p)
			check(sample.texture == stable.texture and sample.height == stable.height and sample.mirror == stable.mirror and sample.profile == stable.profile and sample.tint == stable.tint, "chopping shake preserves exact tree identity")
		game.tree_states[p].shake = 0.0
	var tree_p: Vector2 = game.trees[0]
	var tree_before: float = model_area(game, game.model_spec("tree", tree_p))
	game.tree_states[tree_p].felled = true
	game.rebuild_obstacles()
	var stump_spec: Dictionary = game.model_spec("tree", tree_p)
	var stump_area: float = model_area(game, stump_spec)
	check(str(stump_spec.profile).begins_with("stump_"), "felled tree switches to measured stump contact")
	check(stump_area > 0 and stump_area < tree_before, "stump retains smaller collision footprint")
	check(not game.static_walkable(interior_point(game.model_polygons(stump_spec)[0])), "stump remains solid after tree felling")
	game.tree_states[tree_p].felled = false
	var vein: Dictionary = game.ore_veins[0]
	var ore_before: float = model_area(game, game.model_spec("ore", vein.p, 0))
	game.ore_veins[0].depleted = true
	game.rebuild_obstacles()
	var ore_spec: Dictionary = game.model_spec("ore", vein.p, 0)
	var ore_after: float = model_area(game, ore_spec)
	check(ore_after > 0 and ore_after < ore_before, "depleted ore retains smaller collision footprint")
	check(not game.static_walkable(interior_point(game.model_polygons(ore_spec)[0])), "depleted ore contact remains solid")
	game.ore_veins[0].depleted = false
	game.rebuild_obstacles()
	var ordering: Array[Dictionary] = game.scenery_entries()
	var repeated: Array[Dictionary] = game.scenery_entries()
	check(ordering.size() == repeated.size(), "draw order size stable")
	for index in range(ordering.size()):
		check(ordering[index].id == repeated[index].id, "draw order stable for stationary world")
		if index > 0:
			check(float(ordering[index].depth) >= float(ordering[index - 1].depth) - 0.001, "draw order follows ground depth")
	print("PASS depletion and stable scenery order checked")
	# Use a reachable standing position, then the same 80-unit placement ray as
	# actual controls. Searching only a clear workbench anchor can invent an
	# unreachable player position hidden inside another tree.
	var standing: Vector2 = Vector2.INF
	var facing: Vector2 = Vector2.DOWN
	for y in range(180, 1380, 32):
		for x in range(160, 2080, 32):
			var candidate := Vector2(x, y)
			if not game.walkable(candidate): continue
			game.player = candidate
			for direction in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT]:
				var placement: Vector2 = candidate + direction * 80
				if game.can_place_bench(placement) and game.target_line_clear(placement):
					standing = candidate
					facing = direction
					break
			if standing.is_finite(): break
		if standing.is_finite(): break
	check(standing.is_finite(), "real walkable workbench placement origin exists")
	if standing.is_finite():
		game.player = standing
		game.facing = facing
		game.bag.add("workbench", 1)
		var slot: int = game.bag.first("workbench")
		game.hotbar[0] = game.bag.slots[slot].uid
		game.active_hotbar = 0
		var before: int = game.workbenches.size()
		check(game.place_workbench(), "workbench places from real reachable origin")
		check(game.workbenches.size() == before + 1, "placed bench is registered")
		check(game.walkable(standing), "placed bench keeps player outside collision")
		game.crafting_station = game.nearby_bench()
		check(game.crafting_station >= 0 and game.bench_available(), "new workbench immediately unlocks crafting from reachable origin")
		check(not game.can_place_bench(game.workbenches[-1].p), "second workbench cannot occupy placed bench")
		print("PASS reachable placement position=", standing, " facing=", facing, " station=", game.crafting_station)
	var original_bodies: Array[Dictionary] = game.solid_bodies.duplicate(true)
	var original_npcs: Dictionary = game.npc_states.duplicate(true)
	var representatives: Dictionary = {}
	for body in original_bodies:
		if not representatives.has(body.profile): representatives[body.profile] = body
	var motions: int = 0
	for profile in representatives:
		var body: Dictionary = representatives[profile].duplicate(true)
		var inside: Vector2 = interior_point(body.polygon)
		var shift: Vector2 = Vector2(1100, 750) - inside
		body.polygon = Geometry.transform_polygon(body.polygon, shift)
		body.bounds = Geometry.polygon_bounds(body.polygon)
		body.p += shift
		game.solid_bodies.clear()
		game.solid_bodies.append(body)
		game.npc_home = Vector2(100, 100)
		game.npc_position = Vector2(150, 100)
		# Cardinal rays cross the actual interior without diagonal wall sliding.
		# Large deltas must stop before the far shore rather than skipping solids.
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var reach: float = body.bounds.size.length() + 50.0
			var start: Vector2 = Vector2(1100, 750) - direction * reach
			game.player = start
			check(game.walkable(start), "isolated motion origin is clear: " + profile)
			game.move_player(direction, reach * 2.0 / game.SPEED)
			check(game.walkable(game.player), "large delta player stays outside contour: " + profile)
			check((game.player - Vector2(1100, 750)).dot(direction) < 0.0, "large delta player cannot cross contour: " + profile)
			game.player = Vector2(100, 150)
			game.npc_states = original_npcs.duplicate(true)
			game.npc_states.Rowan.p = Vector2(100, 100)
			game.npc_states.Rowan.wait = 999.0
			var npc: Dictionary = game.npc_states.Ash
			npc.p = start
			npc.wait = 0.0
			npc.path = PackedVector2Array([Vector2(1100, 750) + direction * reach])
			npc.cursor = 0
			npc.replan = 999.0
			npc.route = [Vector2(1100, 750) + direction * reach]
			npc.waypoint = 0
			game.update_npcs(reach * 2.0 / float(npc.speed))
			check(game.npc_walkable(npc.p, "Ash"), "large delta NPC stays outside contour: " + profile)
			check((npc.p - Vector2(1100, 750)).dot(direction) < 0.0, "large delta NPC cannot cross contour: " + profile)
			motions += 2
	game.solid_bodies = original_bodies
	game.npc_states = original_npcs
	print("PASS large-delta actual-profile cardinal motion cases: ", motions)
	print("COLLISION_WORLD_RESULTS checks=", checks, " failures=", failures, " actual_bodies=", body_count, " profiles=", profile_count)
	game.queue_free()
	quit(0 if failures == 0 else 1)
