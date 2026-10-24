extends RefCounted
const Balance = preload("res://survival_balance.gd")
const CAMP := Vector2(455,725)
var encounter_cooldown := 0.0
var shadow_cooldown := Balance.SHADOW_COOLDOWN
var shadow_retry := 0.0
var rest_time := 0.0
var resting := false
var effect_time := 0.0
var illusion_in := 18.0
var illusion_age := 0.0
var illusion: Dictionary = {}
var rng := RandomNumberGenerator.new()
var seen: Dictionary = {}
var last_level := "NORMAL"

func setup(seed_value: int) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value ^ 0x4A11

static func level(value: float) -> String:
	return "NORMAL" if value >= 70 else ("UNSTABLE" if value >= 30 else "CRITICAL")

func light_at(game: Variant, p: Vector2) -> float:
	# Only authored lamps/torches protect; a brighter pre-dawn ambient sky is
	# not a free light source. LOS prevents a torch deterring through a cabin.
	var camp := (1.0 - smoothstep(112.0,205.0,p.distance_to(CAMP))) * 0.96
	var torch := 0.0
	if game.torch_lit and game.torch_fuel > 0 and game.wildlife._line_clear(game,game.player,p):
		torch = (1.0 - smoothstep(60.8,160.0,p.distance_to(game.player))) * 0.98
	var beacon := 0.0
	var glow: Vector3 = game.get("beacon_glow") if game.get("beacon_glow") != null else Vector3.ZERO
	if glow.z > 0.0:
		beacon = (1.0 - smoothstep(70.0,250.0,p.distance_to(Vector2(glow.x,glow.y)))) * 0.97 * glow.z
	return 1.0 - (1.0 - camp) * (1.0 - torch) * (1.0 - beacon)

func threats(game: Variant, radius: float = 210.0) -> Array:
	var result: Array = []
	if game.wildlife == null: return result
	for animal in game.wildlife.animals:
		if not game.wildlife.Data.info(animal.species).predator: continue
		if animal.age < 3.0 or animal.p.distance_to(game.player) > radius: continue
		if game.wildlife._line_clear(game,animal.p,game.player): result.append(animal)
	return result

func update(game: Variant, dt: float) -> void:
	if not game.simulation_running() or dt <= 0: return
	encounter_cooldown = maxf(0,encounter_cooldown-dt)
	shadow_cooldown = maxf(0,shadow_cooldown-dt)
	shadow_retry = maxf(0,shadow_retry-dt)
	effect_time += dt
	var nearby := threats(game)
	var illuminated := light_at(game,game.player) >= 0.45
	var safe: bool = game.player.distance_to(CAMP) < 125.0 and illuminated and nearby.is_empty()
	if safe and not game.moving and game.action.is_empty(): rest_time += dt
	else: rest_time = 0.0
	resting = rest_time >= Balance.REST_DELAY
	var rate := 0.0
	if game.phase == "night" and not illuminated: rate -= Balance.DARK_SANITY_LOSS * (float(game.night_mod("sanity_mult", 1.0)) if game.has_method("night_mod") else 1.0)
	if game.fullness < 10: rate -= Balance.HUNGRY_SANITY_LOSS
	# v0.3.0: the Fallen Ruins whisper, by day as well as by night.
	if game.get("region_world") != null: rate -= game.region_world.haunt_rate(game)
	# alpha-4: sanity only comes back in sunlight, from medicine (main.gd) or a
	# magic stone held in hand (condition.gd). A lit camp stops the dark from
	# draining it, but resting there no longer restores it.
	if game.get("condition") != null: rate += game.condition.sanity_gain(game)
	game.sanity = clampf(game.sanity + rate*dt,0,100)
	# One loss per genuine newly observed encounter, shared cooldown across a pack.
	# Staying in view or opening a menu never refreshes an encounter.
	var current: Dictionary = {}
	for animal in nearby:
		if animal.state not in ["chase","windup","charge_warn","charge","investigate"]: continue
		current[animal.uid] = effect_time
		if not seen.has(animal.uid) and encounter_cooldown <= 0 and animal.state in ["chase","windup","charge_warn","charge","investigate"]:
			game.sanity = maxf(0,game.sanity-Balance.ENCOUNTER_LOSS)
			encounter_cooldown = Balance.ENCOUNTER_COOLDOWN
			game.notify("Danger nearby. Sanity -5. Keep light, prepare a weapon, or break sight.")
	for uid in current: seen[uid] = effect_time
	for uid in seen.keys():
		if effect_time-float(seen[uid]) > 35.0: seen.erase(uid)
	_update_shadow(game,illuminated)
	_update_illusion(game,dt)
	# Falling past each line is announced by condition.gd (several steps).
	last_level = level(game.sanity)

func _update_shadow(game: Variant, illuminated: bool) -> void:
	var safe_conditions: bool = game.phase != "night" or illuminated
	# Shadows fade 5 sanity above the point where they appear (30, or 45 under
	# a blood moon), so a raised threshold cannot dismiss them on arrival.
	var shadow_at: float = float(game.night_mod("shadow_threshold", 30.0)) if game.has_method("night_mod") else 30.0
	# v0.3.0: deep in the ruins a shadow can form in daylight below 50 sanity.
	if game.get("region_world") != null and game.region_world.daylight_shadows(game):
		safe_conditions = false
		shadow_at = maxf(shadow_at, game.region_world.DEEP_SHADOW_SANITY)
	if safe_conditions or game.sanity > shadow_at + 5.0:
		game.wildlife.dismiss_shadow()
		return
	if game.sanity >= shadow_at or shadow_cooldown > 0 or shadow_retry > 0 or game.wildlife.has_shadow(): return
	# Reuse the native wolf body, physical envelope, gait and combat. A distinct
	# violet tint identifies an actual shadow; atmospheric images never collide.
	shadow_retry = 3.0
	if game.wildlife.spawn_shadow(game):
		shadow_cooldown = Balance.SHADOW_COOLDOWN
		game.notify("A shadow is taking shape beyond the dark. Find light or face it with a blade.")

func _update_illusion(game: Variant, dt: float) -> void:
	if not illusion.is_empty():
		illusion_age += dt
		if illusion_age > 2.8: illusion.clear()
	if game.sanity >= 70:
		illusion.clear(); illusion_in = maxf(illusion_in,12.0); return
	illusion_in -= dt
	if illusion_in > 0: return
	illusion_in = rng.randf_range(12,20) if game.sanity < 30 else rng.randf_range(26,42)
	# Existing painted bushes/trees at the edge of vision; no fake attack warning.
	var candidates: Array[Vector2] = []
	for p in game.trees:
		var screen_p: Vector2 = p-game.camera
		if p.distance_to(game.player) > 180 and p.distance_to(game.player) < 430 and screen_p.x > 20 and screen_p.y > 145 and screen_p.x < game.get_viewport_rect().size.x-20 and screen_p.y < game.get_viewport_rect().size.y-100: candidates.append(p)
	if not candidates.is_empty():
		illusion = {"p":candidates[rng.randi_range(0,candidates.size()-1)],"variant":rng.randi_range(0,game.blend_art.size()-1)}
		illusion_age = 0.0

func eat(game: Variant, amount: float) -> void:
	# Called only after an actual finite berry/fish consumption. No timers in UI.
	game.sanity = clampf(game.sanity+maxf(0,amount),0,100)

func draw(game: Variant, screen: Vector2) -> void:
	# alpha-4: the narrowing sight is drawn by condition.gd; only the passing
	# illusions are drawn here.
	if not game.active_exploration() or game.sanity >= 70: return
	if not illusion.is_empty():
		var p: Vector2 = illusion.p-game.camera+Vector2(sin(effect_time*1.7)*4.0,-8)
		var alpha := sin(clampf(illusion_age/2.8,0,1)*PI)*0.20
		game.draw_texture_rect(game.blend_art[illusion.variant],Rect2(p-Vector2(42,46),Vector2(84,65)),false,Color(0.32,0.22,0.42,alpha))
