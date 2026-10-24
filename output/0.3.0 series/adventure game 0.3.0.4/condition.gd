extends RefCounted
## v0.3.0-alpha.4: how low sanity, fullness and health hold the traveler back.
## Every effect grows smoothly as a value falls below its comfort line, so a
## falling bar is felt (slower steps, clumsier hands, narrowing sight, a red or
## hungry edge on the screen) long before it is empty.
##   Sanity 0  : barely able to walk, nearly blind, hands will not work.
##               Only sunlight, medicine or a magic stone held in hand help.
##   Fullness 0: weak and slow, starving (health drains).
##   Health low: limping and slow, a pulsing red edge.

const Regions = preload("res://regions.gd")

const SANITY_COMFORT := 70.0
const FULLNESS_COMFORT := 50.0
const HEALTH_COMFORT := 60.0
# Speed multiplier at the very bottom of each value (they multiply together).
const SANITY_SLOWEST := 0.30
const HUNGER_SLOWEST := 0.55
const INJURY_SLOWEST := 0.55
const MIN_SPEED := 0.22
# How much longer every tool swing / gather takes at the very bottom.
const SANITY_CLUMSY := 0.9
const HUNGER_CLUMSY := 0.6
const INJURY_CLUMSY := 0.5
# At or below this sanity the mind is gone: no gathering, tools or crafting.
const BROKEN_SANITY := 1.0
# Sprinting stops below these.
const SPRINT_SANITY := 12.0
const SPRINT_FULLNESS := 10.0
const SPRINT_HEALTH := 15.0
# Sanity recovery (the only three ways back).
const SUN_SANITY_GAIN := 0.25 # per second in daylight
const RUINS_SUN_FACTOR := 0.0 # the ruins' whispers drown out the sun (they still drain by day)
const STONE_SANITY_GAIN := 0.6 # per second while a magic stone is held in hand
const MEDICINE_SANITY := 35.0

# Warnings shown once each time a value falls past a line (re-armed 6 above).
const WARNINGS := {
	"sanity": [[50.0, "Your thoughts drift. You move a little slower."],
		[30.0, "The edges of the world grow dark. Your hands feel clumsy."],
		[12.0, "You can barely see. Find sunlight, take medicine or hold a magic stone."],
		[1.0, "Your mind is gone dark. You can only stumble. Sunlight, medicine or a magic stone in hand."]],
	"fullness": [[40.0, "Your stomach growls. You feel slower."],
		[20.0, "Weak with hunger. Every step and swing is harder."],
		[1.0, "Starving! You are losing health. Eat something."]],
	"health": [[50.0, "You are hurt. You start to limp."],
		[25.0, "Badly hurt. Use medicine (H) and stay away from danger."],
		[10.0, "You are close to collapse!"]],
}

var armed: Dictionary = {}
var time := 0.0

static func ramp(value: float, comfort: float) -> float:
	return clampf(1.0 - value / comfort, 0.0, 1.0)

func sanity_t(game: Variant) -> float: return ramp(float(game.sanity), SANITY_COMFORT)
func hunger_t(game: Variant) -> float: return ramp(float(game.fullness), FULLNESS_COMFORT)
func injury_t(game: Variant) -> float: return ramp(float(game.health), HEALTH_COMFORT)

func speed_scale(game: Variant) -> float:
	var s := lerpf(1.0, SANITY_SLOWEST, pow(sanity_t(game), 1.6))
	var h := lerpf(1.0, HUNGER_SLOWEST, pow(hunger_t(game), 1.4))
	var i := lerpf(1.0, INJURY_SLOWEST, pow(injury_t(game), 1.4))
	return maxf(MIN_SPEED, s * h * i)

func action_scale(game: Variant) -> float:
	return 1.0 + SANITY_CLUMSY * pow(sanity_t(game), 1.5) + HUNGER_CLUMSY * pow(hunger_t(game), 1.5) + INJURY_CLUMSY * pow(injury_t(game), 1.5)

func stamina_regen_scale(game: Variant) -> float:
	return lerpf(1.0, 0.4, hunger_t(game))

func can_sprint(game: Variant) -> bool:
	return float(game.sanity) >= SPRINT_SANITY and float(game.fullness) >= SPRINT_FULLNESS and float(game.health) >= SPRINT_HEALTH

func broken(game: Variant) -> bool:
	return float(game.sanity) <= BROKEN_SANITY

func holding_stone(game: Variant) -> bool:
	return str(game.selected_item().get("id", "")) == "crystal"

func broken_message() -> String:
	return "Your mind is gone dark. Get to sunlight, take medicine (H) or hold a magic stone."

func sanity_gain(game: Variant) -> float:
	# Per second. Sunlight (by day), plus a magic stone held in hand.
	var gain := 0.0
	if game.phase == "day":
		var ruins: bool = Regions.region_at(game.player) == "ruins"
		gain += SUN_SANITY_GAIN * (RUINS_SUN_FACTOR if ruins else 1.0)
	if holding_stone(game): gain += STONE_SANITY_GAIN
	return gain

func update(game: Variant, dt: float) -> void:
	time += dt
	for key in WARNINGS:
		var value: float = float(game.get(key))
		var lines: Array = WARNINGS[key]
		if not armed.has(key):
			armed[key] = []
			for line in lines: armed[key].append(value > float(line[0]))
		for k in range(lines.size()):
			var at: float = float(lines[k][0])
			if armed[key][k] and value <= at:
				armed[key][k] = false
				game.notify(str(lines[k][1]))
			elif not armed[key][k] and value > at + 6.0:
				armed[key][k] = true

func status_line(game: Variant) -> String:
	if broken(game): return "Mind gone dark: find sunlight"
	var parts: Array[String] = []
	if sanity_t(game) > 0.0: parts.append("uneasy" if float(game.sanity) >= 30 else "losing your mind")
	if hunger_t(game) > 0.0: parts.append("hungry" if float(game.fullness) >= 20 else ("very hungry" if float(game.fullness) > 0 else "starving"))
	if injury_t(game) > 0.0: parts.append("hurt" if float(game.health) >= 25 else "badly hurt")
	if parts.is_empty():
		return "Holding a magic stone: calm returns" if holding_stone(game) and float(game.sanity) < 100 else "Light protects your sanity"
	var slow := roundi((1.0 - speed_scale(game)) * 100.0)
	return ", ".join(parts).capitalize() + (": %d%% slower" % slow if slow >= 3 else "")

# --- Screen feedback ------------------------------------------------------------
func draw(game: Variant, screen: Vector2) -> void:
	if not game.active_exploration(): return
	var top: float = 0.0
	_injury_edge(game, screen, top)
	_hunger_edge(game, screen, top)
	_tunnel(game, screen)

func _tunnel(game: Variant, screen: Vector2) -> void:
	# Sight narrows to a shrinking circle around the traveler as sanity falls.
	var s := sanity_t(game)
	if s <= 0.0: return
	var strength := 0.95 * pow(s, 1.1)
	var inner := lerpf(720.0, 55.0, pow(s, 0.8)) + sin(time * 1.3) * 6.0 * s
	var outer := inner + lerpf(260.0, 75.0, s)
	var far := screen.length() + 40.0
	var center: Vector2 = game.player - game.camera + Vector2(0, -28)
	var dark := Color(0.035, 0.02, 0.06, strength)
	var clear := Color(dark, 0.0)
	var n := 48
	for k in range(n):
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		game.draw_polygon(PackedVector2Array([center + d0 * inner, center + d1 * inner, center + d1 * outer, center + d0 * outer]), PackedColorArray([clear, clear, dark, dark]))
		game.draw_polygon(PackedVector2Array([center + d0 * outer, center + d1 * outer, center + d1 * far, center + d0 * far]), PackedColorArray([dark, dark, dark, dark]))

func _edge(game: Variant, screen: Vector2, top: float, color: Color, depth: float) -> void:
	# A soft band of colour along all four edges of the screen.
	var steps := 12
	for i in range(steps):
		var w := depth / steps
		var c := Color(color, color.a * (1.0 - float(i) / steps))
		game.draw_rect(Rect2(i * w, top, w, screen.y - top), c)
		game.draw_rect(Rect2(screen.x - (i + 1) * w, top, w, screen.y - top), c)
		game.draw_rect(Rect2(0, top + i * w, screen.x, w), c)
		game.draw_rect(Rect2(0, screen.y - (i + 1) * w, screen.x, w), c)

func _hunger_edge(game: Variant, screen: Vector2, top: float) -> void:
	var h := hunger_t(game)
	if h <= 0.0: return
	var growl := 0.85 + 0.15 * sin(time * 1.1)
	_edge(game, screen, top, Color(0.24, 0.17, 0.07, 0.66 * pow(h, 1.0) * growl), lerpf(90.0, 230.0, h))

func _injury_edge(game: Variant, screen: Vector2, top: float) -> void:
	var i := injury_t(game)
	if i <= 0.0: return
	# Heartbeat: faster and stronger as health drops.
	var beat := pow(maxf(0.0, sin(time * lerpf(4.0, 9.0, i))), 6.0)
	_edge(game, screen, top, Color(0.66, 0.05, 0.04, (0.38 + 0.32 * beat) * pow(i, 1.0)), lerpf(100.0, 240.0, i))
