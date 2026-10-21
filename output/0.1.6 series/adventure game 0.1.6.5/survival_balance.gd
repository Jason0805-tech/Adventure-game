extends RefCounted
## One place for survival tuning. Art, physical footprints and gait are unchanged.
const HUNGER_PER_SECOND := 8.0 / 60.0
const STARVATION_DAMAGE := 0.8
const DARK_SANITY_LOSS := 0.35
const HUNGRY_SANITY_LOSS := 0.10
const CAMP_SANITY_GAIN := 0.25
const ENCOUNTER_LOSS := 5.0
const ENCOUNTER_COOLDOWN := 24.0
const SHADOW_COOLDOWN := 50.0
const REST_DELAY := 3.0

const NIGHT_PROFILES = [
		{"wolves":2,"wolf_speed":116.0,"bear_speed":74.0,"charge_speed":150.0,"charge_cooldown":11.0,"pursuit":6.0,"notice":0.88,"grace":8.0,"courage_delay":3.0,"respawn":48.0},
		{"wolves":3,"wolf_speed":118.0,"bear_speed":77.0,"charge_speed":158.0,"charge_cooldown":9.0,"pursuit":8.0,"notice":0.96,"grace":6.0,"courage_delay":2.2,"respawn":40.0},
		{"wolves":3,"wolf_speed":120.0,"bear_speed":80.0,"charge_speed":166.0,"charge_cooldown":7.5,"pursuit":10.0,"notice":1.04,"grace":5.0,"courage_delay":1.5,"respawn":34.0}
]

static func night_profile(night: int) -> Dictionary:
	return NIGHT_PROFILES[clampi(night - 1, 0, 2)]

static func movement_scale(fullness: float) -> float:
	return lerpf(0.92, 1.0, clampf(fullness / 25.0, 0, 1))

static func action_duration(id: String, kind: String, fullness: float) -> float:
	var base := 2.0 if kind == "water" else 0.8
	if id == "iron_axe": base = 0.58
	elif id == "amazing_sword": base = 0.60
	elif id == "stone_knife" or id == "wood_knife": base = 0.65
	return base * lerpf(1.12, 1.0, clampf(fullness / 25.0, 0, 1))
