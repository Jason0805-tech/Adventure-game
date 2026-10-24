extends RefCounted
## v0.2.0 Night Survival 2.0: every night after the first brings one event that
## changes how the night plays, announced at dusk. Modifiers are read by the
## wildlife, sanity, lighting and HUD code through modifier().

const EVENTS := {
	"calm": {"title": "A QUIET NIGHT", "hud": "Quiet night",
		"text": "The forest is calm tonight. Learn the dark: carry light and watch for eyes."},
	"howling": {"title": "HOWLING PACK", "hud": "Howling pack",
		"text": "Wolves howl in the distance. Tonight one more joins, and they hunt together.",
		"extra_wolves": 1, "hunt_bonus": 0.30},
	"fog": {"title": "THICK FOG", "hud": "Thick fog",
		"text": "Fog rolls in. You see less, and so do they. The dark weighs on your mind.",
		"fog": 0.05, "notice_mult": 0.75, "sanity_mult": 1.35, "tint": Color(0.16, 0.18, 0.21)},
	"bear": {"title": "RESTLESS BEAR", "hud": "Restless bear",
		"text": "A bear roams wide tonight, hunting your trail and charging more often.",
		"bear_hunts": true, "charge_mult": 0.6},
	"blood_moon": {"title": "BLOOD MOON", "hud": "Blood moon",
		"text": "A red moon rises. Your mind frays faster and shadows walk sooner.",
		"sanity_mult": 1.6, "shadow_threshold": 45.0, "tint": Color(0.07, 0.008, 0.016)},
}
const SECOND_NIGHT := ["howling", "fog", "bear"]
const LATER_NIGHTS := ["howling", "fog", "bear", "blood_moon"]

var current := "calm"
var history: Array[String] = []
var rng := RandomNumberGenerator.new()

func setup(seed_value: int) -> void:
	current = "calm"; history.clear()
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value ^ 0x5EED

func choose(night: int) -> String:
	# Night 1 is always calm. Later nights never repeat the previous event.
	if night <= 1:
		current = "calm"
	else:
		var pool: Array = (SECOND_NIGHT if night == 2 else LATER_NIGHTS).duplicate()
		if not history.is_empty(): pool.erase(history.back())
		current = pool[rng.randi_range(0, pool.size() - 1)]
	history.append(current)
	return current

func info() -> Dictionary:
	return EVENTS[current]

func modifier(key: String, fallback: Variant) -> Variant:
	return EVENTS[current].get(key, fallback)

func hud_name() -> String:
	return str(EVENTS[current].hud)
