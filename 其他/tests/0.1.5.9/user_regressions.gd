extends SceneTree

# User regression landmarks are hand-annotated from the visible sprites.
# They must stay independent of collision polygon construction. This test
# intentionally detects absent solid bodies, not just malformed existing ones.
const Geometry = preload("res://world_geometry.gd")
var checks: int = 0
var failures: int = 0
var sample_count: int = 0
var free_sample_count: int = 0
var center_only_free_samples: int = 0
var motion_cases: int = 0
var game: Variant

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL user regression: " + label)

func _initialize() -> void:
	call_deferred("_run")

func sample_world(sample: Dictionary, body: Dictionary) -> Vector2:
	var uv := Vector2(float(sample.uv[0]), float(sample.uv[1]))
	if sample.kind == "bank_rock":
		var pool: Rect2 = game.pools[int(body.index)]
		return pool.position + uv * pool.size
	var spec: Dictionary = game.model_spec(str(body.kind), body.p, int(body.index))
	var rect: Rect2 = game.sprite_rect(spec.texture, spec.foot, float(spec.height))
	var point: Vector2 = rect.position + uv * rect.size
	if bool(spec.mirror): point.x = float(spec.foot.x) * 2.0 - point.x
	return point

func own_bodies(sample: Dictionary) -> Dictionary:
	var groups: Dictionary = {}
	var expected_profile: String = str(sample.profile) + ("_rocks" if sample.kind == "bank_rock" else "")
	for body in game.solid_bodies:
		if str(body.kind) != str(sample.kind) or str(body.profile) != expected_profile: continue
		# Each pond stone has its own ID, whereas the source PNG contains all
		# stones. A landmark must lie in a bank-rock body of that same pond;
		# it must not be required to lie inside every unrelated stone there.
		var identity: String = "pond:%d" % int(body.index) if sample.kind == "bank_rock" else str(body.id)
		if not groups.has(identity): groups[identity] = []
		groups[identity].append(body)
	return groups

func add_missing_variant(sample: Dictionary) -> void:
	# The current camp only places one log variant and one crate variant. Exercise
	# alternate visible art through its normal model/body pipeline in this test.
	if sample.kind == "prop" and own_bodies(sample).is_empty():
		var variant: int = int(str(sample.profile).trim_prefix("prop_"))
		var index: int = game.props.size()
		game.props.append({"p": Vector2(1050 + index * 90, 1350), "sprite": variant, "height": 49.0})
		game.append_model_body("prop", game.props[index].p, index)
	elif sample.kind == "ore" and own_bodies(sample).is_empty():
		var variant: int = int(str(sample.profile).trim_prefix("ore_"))
		var index: int = game.ore_veins.size()
		game.ore_veins.append({"p": Vector2(950 + index * 80, 1340), "variant": variant, "hp": 3, "depleted": false})
		game.append_model_body("ore", game.ore_veins[index].p, index)

func inside_own(point: Vector2, bodies: Array) -> bool:
	for body in bodies:
		if Geometry.point_in_polygon_or_boundary(point, body.polygon): return true
	return false

func approach_same_object(point: Vector2, source_bodies: Array, label: String) -> void:
	var center := Vector2(1100, 750)
	var shift: Vector2 = center - point
	var relocated: Array[Dictionary] = []
	var merged := Rect2()
	for original in source_bodies:
		var body: Dictionary = original.duplicate(true)
		body.polygon = Geometry.transform_polygon(body.polygon, shift)
		body.bounds = Geometry.polygon_bounds(body.polygon)
		body.p += shift
		merged = body.bounds if relocated.is_empty() else merged.merge(body.bounds)
		relocated.append(body)
	game.solid_bodies = relocated
	var reach: float = merged.size.length() + 70.0
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var start: Vector2 = center - direction * reach
		game.player = start
		check(game.walkable(start), label + " independent approach begins outside this object: " + str(direction))
		game.move_player(direction, reach * 2.0 / game.SPEED)
		check(game.walkable(game.player), label + " feet remain clear after long frame: " + str(direction))
		check((game.player - center).dot(direction) < -0.01, label + " own solid stops passage from " + str(direction))
		check(not inside_own(game.player, relocated), label + " foot origin never enters its visible solid")
		motion_cases += 1

func _run() -> void:
	var root_path: String = ProjectSettings.globalize_path("res://").path_join("../../tests/0.1.5.9/independent-solid-samples.json").simplify_path()
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(root_path))
	check(document is Dictionary and document.has("samples"), "independent source landmark file is present")
	if not (document is Dictionary and document.has("samples")):
		quit(1)
		return
	game = load("res://main.tscn").instantiate()
	game.resource_seed = 158
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	game.npc_home = Vector2(100, 100)
	game.npc_position = Vector2(150, 100)
	var samples: Array = document.samples
	for sample in samples: add_missing_variant(sample)
	var full_world: Array[Dictionary] = game.solid_bodies.duplicate(true)
	var targets: Array = []
	for sample in samples:
		var label: String = str(sample.profile) + ":" + str(sample.part)
		var instances: Dictionary = own_bodies(sample)
		check(not instances.is_empty(), label + " has its own solid body kind/profile")
		for identity in instances:
			var bodies: Array = instances[identity]
			var point: Vector2 = sample_world(sample, bodies[0])
			var covered: bool = inside_own(point, bodies)
			if sample.get("expect", "solid") == "free":
				check(not covered, label + " leaf canopy has no tree collision at its center")
				if bool(sample.get("actor_footprint_clear", true)):
					var clear_boots: bool = true
					for body in bodies:
						if Geometry.polygons_overlap(game.feet_polygon(point), body.polygon): clear_boots = false
					check(clear_boots, label + " boots beneath distant leaves are not blocked by that tree")
				else:
					# A point on a leaf can be clear while a 28-unit-wide actor
					# capsule touches real neighboring wood. Do not erase that
					# legitimate branch to make a point landmark fit a capsule.
					center_only_free_samples += 1
				free_sample_count += 1
				continue
			check(covered, label + " visible solid covered by the same object, id=" + str(identity) + " point=" + str(point))
			check(not game.static_walkable(point), label + " rejects player feet in full world")
			if covered:
				var target_bodies: Array = bodies
				if sample.kind in ["bank_rock", "tree"]:
					# Motion is blocked only by the stone containing this visible
					# landmark, with all water and neighboring stones removed.
					target_bodies = []
					for body in bodies:
						if Geometry.point_in_polygon_or_boundary(point, body.polygon): target_bodies.append(body)
				targets.append({"point": point, "bodies": target_bodies, "label": label})
			sample_count += 1
	print("PASS independent visible-solid coverage samples=", sample_count, " free_canopy_samples=", free_sample_count, " failures=", failures)
	for target in targets: approach_same_object(target.point, target.bodies, target.label)
	game.solid_bodies = full_world
	print("USER_REGRESSION_RESULTS checks=", checks, " failures=", failures, " visible_samples=", sample_count, " free_canopy_samples=", free_sample_count, " center_only_near_branch_samples=", center_only_free_samples, " same_object_motion_cases=", motion_cases)
	game.queue_free()
	quit(0 if failures == 0 else 1)
