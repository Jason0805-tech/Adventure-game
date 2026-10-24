extends RefCounted
## v0.3.0 World Expansion: the world grows from one forest into three regions.
## Whispering Woods keeps the original painted map in its original place; the
## River Valley lies east and the Fallen Ruins south. This file is pure layout
## data and geometry, so tests and every system read the same map.

const WORLD := Vector2(3600, 2600)
const FOREST := Rect2(0, 0, 2200, 1500)
const VALLEY := Rect2(2200, 0, 1400, 2600)
const RUINS := Rect2(0, 1500, 2200, 1100)
const REGION_ORDER := ["forest", "valley", "ruins"]
const INFO := {
	"forest": {"name": "Whispering Woods", "short": "Woods", "rect": FOREST,
		"text": "Home woods. Timber, berries and iron ore. Wolves hunt here at night."},
	"valley": {"name": "River Valley", "short": "Valley", "rect": VALLEY,
		"text": "Cross at the bridge or the fords: deep water cannot be waded. Reeds and trout here."},
	"ruins": {"name": "Fallen Ruins", "short": "Ruins", "rect": RUINS,
		"text": "The stones whisper. Your mind frays faster here, even by day."},
}

# --- River: x as a smooth function of y, flowing north to south -------------
const RIVER_POINTS := [Vector2(2960, -60), Vector2(2905, 300), Vector2(2865, 760), Vector2(2935, 1150), Vector2(2990, 1550), Vector2(2925, 1950), Vector2(2860, 2350), Vector2(2890, 2680)]
const RIVER_HALF := 85.0 # deep water half-width
const BANK := 70.0 # pebble shore beyond the water
# Crossings over the river (world y ranges). Fords are shallow and slow;
# the bridge deck is dry plank.
const NORTH_FORD := Vector2(200, 318)
# alpha-4: the bridge band is exactly the painted plank deck between the two
# railings (it was 712-800, wider than the deck, so you could walk across the
# water beside the bridge).
const BRIDGE := Vector2(728, 784)
# Where the plank deck sits in valley-bridge-deck.png (fractions of its height).
const BRIDGE_DECK_TOP := 0.20
const BRIDGE_DECK_BOTTOM := 0.58
const SOUTH_FORD := Vector2(2005, 2125)
const FORD_SPEED := 0.55

# --- Roads (polyline, half width). They join the painted forest roads at the
# map edge: north trail y~258, main road y~756, south road x~1717. ----------
const PATHS := [
	{"id": "valley_north", "half": 44.0, "points": [Vector2(2150, 258), Vector2(2780, 258), Vector2(3060, 258), Vector2(3300, 210), Vector2(3480, 330)]},
	{"id": "valley_main", "half": 60.0, "points": [Vector2(2150, 756), Vector2(2760, 756), Vector2(2990, 756), Vector2(3120, 820), Vector2(3215, 1010), Vector2(3175, 1230)]},
	{"id": "valley_south", "half": 46.0, "points": [Vector2(2150, 2065), Vector2(2760, 2065), Vector2(3060, 2065), Vector2(3240, 2170), Vector2(3300, 2300)]},
	{"id": "ruins_main", "half": 66.0, "points": [Vector2(1717, 1460), Vector2(1717, 1700), Vector2(1560, 1880), Vector2(1330, 1995), Vector2(1100, 2050)]},
	{"id": "ruins_east", "half": 46.0, "points": [Vector2(1100, 2050), Vector2(1480, 2090), Vector2(1880, 2072), Vector2(2250, 2065)]},
	{"id": "ruins_west", "half": 42.0, "points": [Vector2(1100, 2050), Vector2(760, 2010), Vector2(520, 1905), Vector2(330, 1840)]},
]

# --- Ruins -------------------------------------------------------------------
const PLAZA := Vector2(1100, 2050)
const PLAZA_RADIUS := 250.0
const DEEP_RUINS := 480.0 # within this of the plaza, shadows walk by day
const FALLEN_GATE := Vector2(1717, 1640)
const SUNKEN_WELL := Vector2(330, 1840)
# --- Valley ------------------------------------------------------------------
const OLD_FERRY := Vector2(3130, 1260)
# The ferry dock (valley-dock.png, 355 x 423) stands in the water at the east
# bank. alpha-4: its plank top is walkable ground, so the river is cut there.
const DOCK_WIDTH := 104.0
const DOCK_ASPECT := 423.0 / 355.0
const DOCK_DECK := Rect2(0.10, 0.14, 0.80, 0.48) # plank top, fractions of the image
const WILLOW_BEND := Vector2(2600, 1650)
const DRIFTWOOD_SHORE := Vector2(3260, 2260)

static func region_at(p: Vector2) -> String:
	if VALLEY.has_point(p) or p.x >= VALLEY.position.x: return "valley"
	if p.y >= RUINS.position.y: return "ruins"
	return "forest"

static func river_x(y: float) -> float:
	# Catmull-Rom through RIVER_POINTS, parametrised by y.
	var pts: Array = RIVER_POINTS
	var i := 0
	while i < pts.size() - 2 and y > pts[i + 1].y: i += 1
	var p0: Vector2 = pts[maxi(0, i - 1)]
	var p1: Vector2 = pts[i]
	var p2: Vector2 = pts[i + 1]
	var p3: Vector2 = pts[mini(pts.size() - 1, i + 2)]
	var t: float = clampf((y - p1.y) / maxf(1.0, p2.y - p1.y), 0.0, 1.0)
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1.x) + (-p0.x + p2.x) * t + (2.0 * p0.x - 5.0 * p1.x + 4.0 * p2.x - p3.x) * t2 + (-p0.x + 3.0 * p1.x - 3.0 * p2.x + p3.x) * t3)

static func river_offset(p: Vector2) -> float:
	# Signed horizontal distance from the river centre (negative = west bank).
	return p.x - river_x(p.y)

static func crossing_at(y: float) -> String:
	if y >= NORTH_FORD.x and y <= NORTH_FORD.y: return "north_ford"
	if y >= BRIDGE.x and y <= BRIDGE.y: return "bridge"
	if y >= SOUTH_FORD.x and y <= SOUTH_FORD.y: return "south_ford"
	return ""

static func in_water(p: Vector2) -> bool:
	return absf(river_offset(p)) < RIVER_HALF

static func in_ford(p: Vector2) -> bool:
	return in_water(p) and crossing_at(p.y).ends_with("ford")

static func on_bridge(p: Vector2) -> bool:
	return absf(river_offset(p)) < RIVER_HALF + 34.0 and crossing_at(p.y) == "bridge"

static func dock_art_rect() -> Rect2:
	return Rect2(Vector2(river_x(OLD_FERRY.y) + RIVER_HALF - 76.0, OLD_FERRY.y - 80.0), Vector2(DOCK_WIDTH, DOCK_WIDTH * DOCK_ASPECT))

static func dock_walk_rect() -> Rect2:
	var art := dock_art_rect()
	return Rect2(art.position + DOCK_DECK.position * art.size, DOCK_DECK.size * art.size)

static func on_dock(p: Vector2) -> bool:
	return dock_walk_rect().has_point(p)

static func deep_water(p: Vector2) -> bool:
	return in_water(p) and crossing_at(p.y) == "" and not on_dock(p)

static func river_quads() -> Array[PackedVector2Array]:
	# Deep water as small convex quads, leaving gaps at the bridge and fords.
	var breaks: Array[float] = []
	var y := -40.0
	while y < WORLD.y + 40.0:
		breaks.append(y); y += 40.0
	var dock := dock_walk_rect()
	for edge in [NORTH_FORD.x, NORTH_FORD.y, BRIDGE.x, BRIDGE.y, SOUTH_FORD.x, SOUTH_FORD.y, dock.position.y, dock.end.y]: breaks.append(edge)
	breaks.sort()
	var quads: Array[PackedVector2Array] = []
	for i in range(breaks.size() - 1):
		var y0: float = breaks[i]
		var y1: float = breaks[i + 1]
		if y1 - y0 < 0.5 or crossing_at((y0 + y1) * 0.5) != "": continue
		var a := river_x(y0)
		var b := river_x(y1)
		var east_a := a + RIVER_HALF
		var east_b := b + RIVER_HALF
		var mid := (y0 + y1) * 0.5
		if mid > dock.position.y and mid < dock.end.y:
			# Water stops at the dock's west edge; the planks are dry ground.
			east_a = minf(east_a, dock.position.x); east_b = minf(east_b, dock.position.x)
		quads.append(PackedVector2Array([Vector2(a - RIVER_HALF, y0), Vector2(east_a, y0), Vector2(east_b, y1), Vector2(b - RIVER_HALF, y1)]))
	return quads

static func bridge_art_rect(aspect: float) -> Rect2:
	# The painted bridge, sized and placed so its plank deck covers BRIDGE.
	# aspect = image width / height.
	var h: float = (BRIDGE.y - BRIDGE.x) / (BRIDGE_DECK_BOTTOM - BRIDGE_DECK_TOP)
	var w: float = h * aspect
	var x := river_x((BRIDGE.x + BRIDGE.y) * 0.5)
	return Rect2(Vector2(x - w * 0.5, BRIDGE.x - BRIDGE_DECK_TOP * h), Vector2(w, h))

static func bridge_rect() -> Rect2:
	var x := river_x((BRIDGE.x + BRIDGE.y) * 0.5)
	return Rect2(Vector2(x - RIVER_HALF - 46.0, BRIDGE.x), Vector2(RIVER_HALF * 2.0 + 92.0, BRIDGE.y - BRIDGE.x))

static func ford_rect(name: String) -> Rect2:
	var band: Vector2 = NORTH_FORD if name == "north_ford" else SOUTH_FORD
	var x := river_x((band.x + band.y) * 0.5)
	return Rect2(Vector2(x - RIVER_HALF - 12.0, band.x), Vector2(RIVER_HALF * 2.0 + 24.0, band.y - band.x))

static func path_distance(p: Vector2) -> float:
	# Distance beyond the nearest road's edge (<= 0 means on the road).
	var best := INF
	for path in PATHS:
		var pts: Array = path.points
		for i in range(pts.size() - 1):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			best = minf(best, p.distance_to(q) - float(path.half))
	return best

static func on_path(p: Vector2, margin: float = 0.0) -> bool:
	if FOREST.has_point(p):
		return absf(p.y - 760) < 78 + margin or absf(p.x - 1700) < 78 + margin
	return path_distance(p) < margin

static func deep_ruins(p: Vector2) -> bool:
	return p.distance_to(PLAZA) < DEEP_RUINS

static func flagstone_weight(p: Vector2) -> float:
	# Paved plaza and old streets around it, broken into patches.
	if not RUINS.grow(-4).has_point(p): return 0.0
	var plaza := 1.0 - smoothstep(PLAZA_RADIUS - 40.0, PLAZA_RADIUS + 30.0, p.distance_to(PLAZA))
	var street := 0.0
	if p.distance_to(PLAZA) < 760.0:
		street = 1.0 - smoothstep(20.0, 70.0, path_distance(p) + 46.0)
	var patch := 0.5 + 0.5 * sin(p.x * 0.011 + sin(p.y * 0.007) * 2.0) * cos(p.y * 0.013 - p.x * 0.004)
	return clampf(maxf(plaza, street * (0.55 + 0.45 * patch)), 0.0, 1.0)

# --- Ground materials ----------------------------------------------------------
# Order matches region_ground.gd: weights for each ground texture at p.
const MATERIALS := ["meadow", "valley_grass", "bank", "water", "ford", "flagstone", "dry_grass", "path"]

static func material_weights(p: Vector2) -> PackedFloat32Array:
	var w := PackedFloat32Array(); w.resize(MATERIALS.size()); w.fill(0.0)
	if FOREST.has_point(p):
		w[0] = 1.0
		return w
	if region_at(p) == "valley":
		var off := absf(river_offset(p))
		var crossing := crossing_at(p.y)
		if off < RIVER_HALF:
			w[4 if crossing.ends_with("ford") else 3] = 1.0
		elif off < RIVER_HALF + BANK:
			w[2] = 1.0
		else:
			w[1] = 1.0
	else:
		var flag := flagstone_weight(p)
		w[5] = flag; w[6] = 1.0 - flag
	if not in_water(p) and path_distance(p) < 0.0 and not (region_at(p) == "ruins" and flagstone_weight(p) > 0.6):
		for i in range(w.size()): w[i] = 0.0
		w[7] = 1.0
	return w
