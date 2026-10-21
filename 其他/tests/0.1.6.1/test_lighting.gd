extends SceneTree
const Lighting = preload("res://world_lighting.gd")
class World:
	extends Node2D
	var phase := "day"
	var day_time := 0.0
	var day_duration := 180.0
	var phase_time := 0.0
	var dusk_duration := 6.0
	var night_elapsed := 0.0
	var night_duration := 90.0
	var elapsed := 0.0
	var player := Vector2(1100, 1100)
	var camera := Vector2(550, 700)
	var torch_lit := false
	var torch_fuel := 120.0
	var solid_bodies: Array = []
	var animal_metadata := {}
	var wildlife: Variant
	func body_active(_body: Dictionary) -> bool: return true
	func animal_pose(_animal: Dictionary) -> Dictionary:
		return {"direction": 0, "frame": 0, "anchor": Vector2(192,320), "scale":0.3}
class Animals:
	extends RefCounted
	var list: Array = []
	func entries() -> Array: return list
var checks := 0
var failures: Array = []
func check(test: bool, description: String) -> void:
	checks += 1
	if not test: failures.append(description)
func _initialize() -> void:
	var w := World.new()
	root.add_child(w)
	var light := Lighting.new()
	# Validate time keys, all boundaries and no single tick lighting jumps.
	check(absf(light.atmosphere(w).darkness - 0.36) < 0.0001, "Dawn is visible and warm")
	w.day_time = 81
	check(light.atmosphere(w).darkness < 0.01, "Noon has clear native-colour exposure")
	w.day_time = 180
	var evening: float = light.atmosphere(w).darkness
	check(absf(evening - 0.52) < 0.0001, "Evening is visibly dimmer")
	w.phase = "dusk"
	check(absf(evening - light.atmosphere(w).darkness) < 0.0001, "Day to dusk is continuous")
	w.phase_time = 6
	var dusk: float = light.atmosphere(w).darkness
	w.phase = "night"
	check(absf(dusk - light.atmosphere(w).darkness) < 0.0001, "Dusk to night is continuous")
	w.night_elapsed = 40
	check(light.atmosphere(w).darkness > 0.97, "Midnight is almost black beyond light")
	check(light.sample(w, w.player + Vector2(300,0)) < 0.03, "Night without torch hides distant ground")
	check(light.sample(w, w.player + Vector2(25,0)) < 0.03, "No automatic free player lantern")
	check(light.sample(w, w.player) <= 0.14, "Only the boots have faint moon visibility")
	w.torch_lit = true
	check(light.sample(w, w.player) > 0.97, "Lit crafted torch illuminates the player")
	check(light.sample(w, w.player + Vector2(64,0)) > 0.97, "Inner two metres are brightly visible")
	check(light.sample(w, w.player + Vector2(128,0)) > 0.18, "Torch has a soft outer penumbra")
	check(light.sample(w, w.player + Vector2(160,0)) < 0.03, "Torch stops at approximately five metres")
	var previous := 1.0
	for distance in range(0,181):
		var exposure := light.sample(w, w.player + Vector2(distance,0))
		check(exposure <= previous + 0.00001, "Torch falloff is monotonic at %d" % distance)
		previous = exposure
	w.torch_fuel = 0
	check(light.sample(w,w.player) < 0.14, "An exhausted torch cannot reveal the map")
	check(light.sample(w,Vector2(455,725)) > 0.95, "Camp fire stays lit without player torch")
	check(light.sample(w,Vector2(455+160,725)) > 0.4, "Safe-camp boundary remains legible")
	w.night_elapsed = 90
	var end_night: float = light.atmosphere(w).darkness
	w.phase = "result"
	check(absf(light.atmosphere(w).darkness - end_night) < 0.0001, "Night to dawn result is continuous")
	w.phase = "day"; w.day_time = 0
	check(absf(light.atmosphere(w).darkness - end_night) < 0.0001, "Dawn result to new day is continuous")
	var max_tick_change := 0.0
	for phase in ["day","dusk","night"]:
		w.phase = phase
		var duration: float = w.day_duration if phase == "day" else (w.dusk_duration if phase == "dusk" else w.night_duration)
		var previous_dark := 0.36 if phase == "day" else (0.52 if phase == "dusk" else 0.95)
		for tick in range(int(duration * 60) + 1):
			if phase == "day": w.day_time = tick/60.0
			elif phase == "dusk": w.phase_time = tick/60.0
			else: w.night_elapsed = tick/60.0
			var dark: float = light.atmosphere(w).darkness
			max_tick_change = maxf(max_tick_change,absf(dark-previous_dark)); previous_dark=dark
	check(max_tick_change < 0.003, "Maximum per-tick lighting step stays smooth")
	# Real animal list controls eyes; no invented eyes in empty woods.
	w.phase = "night"; w.night_elapsed = 40; w.torch_lit = false; w.torch_fuel = 120
	w.wildlife = Animals.new()
	check(light.eye_entries(w).is_empty(), "Empty woods never draw invented eyes")
	w.animal_metadata = {"wolf":{"poses":[[{"eyes":[[185,200],[199,200]]}]]},"bear":{"poses":[[{"eyes":[[182,210],[202,210]]}]]}}
	var wolf := {"uid":1,"species":"wolf","p":w.player+Vector2(120,0),"alpha":1.0}
	w.wildlife.list = [wolf]
	check(light.eye_entries(w).size()==2, "A real dark wolf has exactly its two registered eyes")
	w.torch_lit = true
	check(light.eye_entries(w).is_empty(), "A torch reveals the animal, suppressing floating eye glows")
	w.torch_lit = false
	w.wildlife.list = [{"uid":2,"species":"bear","p":w.player+Vector2(150,0),"alpha":1.0}]
	var bear_eyes: Array = light.eye_entries(w)
	check(bear_eyes.size()==2 and bear_eyes[0].color.g > bear_eyes[0].color.r, "Bear dark eyes use muted green")
	w.wildlife.list = [wolf]
	w.solid_bodies = [{"kind":"house","polygon":PackedVector2Array([w.player+Vector2(40,-50),w.player+Vector2(80,-50),w.player+Vector2(80,50),w.player+Vector2(40,50)])}]
	check(light.eye_entries(w).is_empty(), "An opaque solid house blocks eye visibility")
	w.solid_bodies[0].kind = "water"
	check(light.eye_entries(w).size()==2, "Water does not block eye visibility")
	w.solid_bodies.clear()
	w.wildlife.list[0].p = w.player+Vector2(301,0)
	check(light.eye_entries(w).is_empty(), "Eyes do not reveal distant enemies")
	w.wildlife.list[0].p = w.player+Vector2(120,0)
	w.elapsed = 4.2+0.43-0.02-0.731
	check(light.eye_entries(w).is_empty(), "Predator blinks use the simulation clock")
	w.elapsed=0
	w.phase="day"; w.day_time=80
	check(light.eye_entries(w).is_empty(), "No glowing daytime eyes")
	# Actual native Canvas triangles, alpha range and field size.
	w.phase="night";w.night_elapsed=40;w.torch_lit=true
	var mesh := light.darkness_mesh(w,Vector2(1100,720))
	var arrays: Array = mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size(), "Each native mesh vertex has its actual exposure")
	check(arrays[Mesh.ARRAY_INDEX].size() > 10000, "Lighting uses a smooth field across the viewport")
	for color in arrays[Mesh.ARRAY_COLOR]:
		check(color.a >= 0 and color.a <= 1, "All fog alpha values are valid")
	print("LIGHTING_CHECKS ", checks, " failures=",failures.size()," maximum_tick_change=",max_tick_change)
	for failure in failures: printerr("FAIL ",failure)
	w.queue_free()
	quit(0 if failures.is_empty() else 1)
