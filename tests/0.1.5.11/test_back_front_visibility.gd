extends SceneTree
## Independent visibility test. Physics locates a legal contact; actual ordered
## Canvas calls determine whether the character is covered by the named model.
## Neither expected visibility nor opacity is inferred from runtime depth values.
const OUT := "res://../../tests/0.1.5.11/"
var game: Variant
var images: Dictionary = {}
var results: Array = []
var failures: Array = []
var captures: Array = []
var full_world: Array[Dictionary] = []
var baseline := false
var tag := "final"

func _initialize() -> void:
	call_deferred("run")

func pixels(path: String) -> Image:
	if not images.has(path): images[path] = Image.load_from_file(path)
	return images[path]

func alpha_at(command: Dictionary, screen: Vector2) -> float:
	var transform: Array = command.transform
	var scale := Vector2(float(transform[3]), float(transform[4]))
	if scale.x == 0 or scale.y == 0: return 0.0
	var point := (screen - Vector2(transform[0], transform[1])).rotated(-float(transform[2])) / scale
	var data: Array = command.rect
	var rect := Rect2(data[0], data[1], data[2], data[3])
	if not rect.has_point(point): return 0.0
	var uv := (point - rect.position) / rect.size
	var image := pixels(command.texture.path)
	var source := Rect2(Vector2.ZERO, Vector2(image.get_width(), image.get_height()))
	if command.has("source"):
		var region: Array = command.source
		source = Rect2(region[0], region[1], region[2], region[3])
	var sample := source.position + uv * source.size
	return image.get_pixel(clampi(int(sample.x), 0, image.get_width() - 1), clampi(int(sample.y), 0, image.get_height() - 1)).a * float(command.color[3])

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label)

func save_capture(name: String) -> void:
	var all: Array = game.commands
	var world: Array = []
	for command in all:
		var transform: Array = command.transform
		if absf(float(transform[0])) < 0.0001 and absf(float(transform[1])) < 0.0001: break
		world.append(command)
	game.commands = world
	var filename := "visibility-" + tag + "-" + name
	game.save_capture(filename, 440, 340)
	game.commands = all
	captures.append({"name": name, "file": filename, "player": [game.player.x, game.player.y], "facing": [game.facing.x, game.facing.y], "walkable": game.walkable(game.player)})

func target_textures(entry: Dictionary) -> Dictionary:
	var keys: Dictionary = {}
	for paint in game.paint_entries():
		if str(paint.id).begins_with(str(entry.id) + ":") and paint.has("texture"):
			keys[str(paint.texture.get_instance_id())] = true
	var spec: Dictionary = game.model_spec(str(entry.kind), entry.p, int(entry.index))
	if not spec.is_empty():
		keys[str(spec.texture.get_instance_id())] = true
		var rect: Rect2 = game.sprite_rect(spec.texture, spec.foot, float(spec.height))
		var display: Texture2D = game.paint_density.prepare_rect(spec.texture, rect.size)
		keys[str(display.get_instance_id())] = true
	return keys

func measure(entry: Dictionary, label: String, mode: String, save: bool = false) -> void:
	game.camera = game.player - Vector2(220, 230)
	var keys := target_textures(entry)
	game.reset_capture()
	game._draw()
	var avatar_key := str(game.avatar_unarmed.get_instance_id())
	var actor: Dictionary = {}
	var own: Array = []
	var post: Array = []
	var seen := false
	for command in game.commands:
		if command.kind != "texture": continue
		var filename := str(command.texture.path)
		if filename.ends_with("-" + avatar_key + ".png"):
			actor = command
			seen = true
			continue
		var belongs := false
		for key in keys:
			if filename.ends_with("-" + str(key) + ".png"):
				belongs = true
				break
		if not belongs: continue
		# Shared atlases can occur at many world positions. Keep only this model's
		# own transformed origin, except separately cropped pond stone textures.
		var origin: Vector2 = Vector2(command.transform[0], command.transform[1]) + game.camera
		if entry.kind != "bank_rock":
			var spec: Dictionary = game.model_spec(str(entry.kind), entry.p, int(entry.index))
			if origin.distance_to(spec.foot) > 0.1: continue
		own.append(command)
		if seen: post.append(command)
	check(not actor.is_empty(), label + " actor paint exists")
	if actor.is_empty(): return
	var actor_image := pixels(actor.texture.path)
	var rect: Array = actor.rect
	var source: Array = actor.source
	var source_scale := Vector2(float(source[2]) / 96.0, float(source[3]) / 160.0)
	var samples := 0
	var overlap := 0
	var covered := 0
	var surviving := 0.0
	var overlap_surviving := 0.0
	var min_surviving := 1.0
	for y in range(16, 144, 4):
		for x in range(12, 85, 4):
			if actor_image.get_pixel(int(source[0]) + int(x * source_scale.x), int(source[1]) + int(y * source_scale.y)).a < 0.85: continue
			var point := Vector2(float(rect[0]) + x / 96.0 * float(rect[2]), float(rect[1]) + y / 160.0 * float(rect[3])) + Vector2(actor.transform[0], actor.transform[1])
			var opacity := 0.0
			for command in own: opacity = 1.0 - (1.0 - opacity) * (1.0 - alpha_at(command, point))
			var survival := 1.0
			for command in post: survival *= 1.0 - alpha_at(command, point)
			samples += 1
			surviving += survival
			min_surviving = minf(min_surviving, survival)
			if opacity > 0.05:
				overlap += 1
				overlap_surviving += survival
			if survival < 0.95: covered += 1
	var mean := surviving / maxi(1, samples)
	var overlap_mean := overlap_surviving / maxi(1, overlap)
	var pass_test := true
	if mode == "front":
		pass_test = mean >= 0.985 and min_surviving >= 0.75
	elif mode == "overhead":
		# A roof/canopy/lintel must visibly remain above the actor, while enough
		# actor contribution survives to locate them. Always-on-top fails too.
		pass_test = overlap >= 3 and covered >= 3 and overlap_mean >= 0.20 and overlap_mean < 0.98
	elif mode == "back":
		# Low scenery can hide lower legs normally. Count non-overlap explicitly.
		pass_test = overlap < 3 or covered >= 1
	check(pass_test, label + " actual alpha " + mode)
	results.append({"label": label, "mode": mode, "player": [game.player.x, game.player.y], "walkable_full_world": game.walkable(game.player), "opaque_actor_samples": samples, "model_overlap_samples": overlap, "covered_samples": covered, "mean_surviving_opacity": mean, "overlap_mean_surviving_opacity": overlap_mean, "minimum_surviving_opacity": min_surviving, "pass": pass_test, "target_texture_count": keys.size()})
	if save: save_capture(label)

func own_bodies(entry: Dictionary) -> Array[Dictionary]:
	var own: Array[Dictionary] = []
	for body in full_world:
		if str(body.id) == str(entry.id) and game.body_active(body): own.append(body)
	return own

func contact(entry: Dictionary, direction: Vector2, fraction: float = 0.5) -> bool:
	var own := own_bodies(entry)
	if own.is_empty(): return false
	var bounds: Rect2 = own[0].bounds
	for body in own: bounds = bounds.merge(body.bounds)
	game.solid_bodies = own
	var x := lerpf(bounds.position.x, bounds.end.x, fraction)
	game.player = Vector2(x, bounds.end.y + 40 if direction.y < 0 else bounds.position.y - 40)
	game.facing = direction
	game.move_player(direction, (bounds.size.y + 90) / game.SPEED)
	var hits: bool = not game.walkable(game.player + direction * 3)
	game.solid_bodies.assign(full_world)
	return hits

func test_model(entry: Dictionary, label: String, overhead: bool, save: bool) -> void:
	if contact(entry, Vector2.UP): measure(entry, label + "-front", "front", save)
	if contact(entry, Vector2.DOWN): measure(entry, label + "-back", "overhead" if overhead else "back", save)

func run() -> void:
	baseline = "baseline" in OS.get_cmdline_user_args()
	if baseline: tag = "baseline"
	game = load(OUT + ("baseline_visual_snapshot_game.gd" if baseline else "visual_snapshot_game.gd")).new()
	game.resource_seed = 159
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children(): child.set_process(false)
	game.npc_home = Vector2(50,1450)
	game.npc_position = Vector2(90,1450)
	game.message_time = 0
	game.show_collision = false
	game.day_time = 30
	game.elapsed = 0
	full_world = game.solid_bodies.duplicate(true)
	test_model(game.scenery_entry("cabin", Vector2(350,635)), "cabin", true, true)
	var gate: Dictionary = game.scenery_entry("gate", game.gate + Vector2(0,30))
	for y in [215, 245, 275, 305]:
		game.player = Vector2(1994,y)
		game.facing = Vector2.UP
		measure(gate, "gate-center-%d" % y, "overhead" if y <= 275 else "front", true)
	var variants: Dictionary = {}
	for point in game.trees:
		var spec: Dictionary = game.model_spec("tree", point)
		if variants.has(spec.profile): continue
		# An instance cropped by the map border cannot be approached from behind.
		# Select another actual instance rather than counting unreachable contact.
		if point.x < 110 or point.x > 2090 or point.y < 220 or point.y > 1380: continue
		variants[spec.profile] = true
		test_model(game.scenery_entry("tree", point), str(spec.profile), true, true)
	var prop_variants: Dictionary = {}
	for index in range(game.props.size()):
		var entry: Dictionary = game.scenery_entry("prop", game.props[index].p, index)
		var profile: String = game.model_spec("prop", entry.p, index).profile
		if prop_variants.has(profile): continue
		prop_variants[profile] = true
		test_model(entry, profile, false, true)
	for index in range(game.workbenches.size()):
		test_model(game.scenery_entry("bench", game.workbenches[index].p, index), "bench-%d" % index, false, index == 0)
	var ores: Dictionary = {}
	for index in range(game.ore_veins.size()):
		var profile: String = game.model_spec("ore", game.ore_veins[index].p, index).profile
		if ores.has(profile): continue
		ores[profile] = true
		test_model(game.scenery_entry("ore", game.ore_veins[index].p, index), profile, false, true)
	for body in full_world:
		if body.kind != "bank_rock": continue
		var entry := {"kind":"bank_rock", "p":body.p, "index":body.index, "id":body.id}
		test_model(entry, str(body.id).replace(":", "-"), false, str(body.id) in ["bank_rock:0:1", "bank_rock:1:0", "bank_rock:2:1"])
	var report := {"version":"0.1.5.11", "tag":tag, "checks":results.size(), "failures":failures, "results":results, "captures":captures, "method":"Actual ordered Canvas texture calls alpha-composited over opaque HD character source samples at legal own-body front/back contacts, plus independently placed arch-center poses. Full-world walkability reported separately; physics route suite is independent. Software replay, not native GPU/manual playthrough."}
	var file := FileAccess.open(OUT + "back-front-visibility-" + tag + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BACK_FRONT_VISIBILITY ", tag, " checks=", results.size(), " failures=", failures.size())
	for failure in failures: print("VISIBILITY_FAILURE ", failure)
	game.queue_free()
	quit(0 if baseline or failures.is_empty() else 1)
