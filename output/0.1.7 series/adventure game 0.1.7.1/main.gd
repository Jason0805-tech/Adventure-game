extends Node2D
# v0.1.7: beacon main quest; separate solid ground footprints, overhead paint and contact depth.
const WORLD := Vector2(2200, 1500)
const SPEED := 108.0
@export var day_duration: float = 120.0
@export var dusk_duration: float = 6.0
@export var night_duration: float = 90.0
var day_time := 0.0
var night_elapsed := 0.0
var last_survived_night := 0
var player := Vector2(360, 760)
var camera := Vector2.ZERO
var facing := Vector2.DOWN
var fullness := 100
var health := 100.0
var sanity := 100.0
var survival = preload("res://sanity_system.gd").new()
var beacon = preload("res://beacon_quest.gd").new()
var map_view = preload("res://map_view.gd").new()
var map_open := false # M: world map; the world keeps running while it is open
var beacon_glow := Vector3.ZERO # x, y, strength of the beacon fire for lighting
var stamina := 100.0
var sprinting := false
var stamina_exhausted := false # empty stamina must refill to STAMINA_RECOVER first
var stamina_rest := 0.0
var mobile_sprint := false # mobile Run button toggles sprint
var mobile_sprint_used := false # Run stays armed until the player has run and stopped
# Press feedback: a pressed button shrinks, then springs back, so players can
# see that the press registered. id -> seconds remaining.
const PRESS_TIME := 0.24
var press_fx: Dictionary = {}
var feedback_hotbar := 0
const Balance = preload("res://survival_balance.gd")
var scout_rewarded := false
var hunger_elapsed := 0.0
@export var resource_seed: int = 0
var props: Array[Dictionary] = []
var harvest_art: Array[Texture2D] = []
var prop_art: Array[Texture2D] = []
var status_art: Array[Texture2D] = []
var avatar_unarmed: Texture2D
var avatar_armed: Texture2D
var held_weapon_art: Array[Texture2D] = []
const FACING_ANGLES := [0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330]
const ATLAS_PIXEL_SCALE := 2.0
const AVATAR_CELL := Vector2(96, 160) * ATLAS_PIXEL_SCALE
const AVATAR_ANCHOR := Vector2(48, 134) * ATLAS_PIXEL_SCALE
const AVATAR_SCALE := 0.80 / ATLAS_PIXEL_SCALE
var night := 1
var survived := 0
var phase := "day"
var phase_time := 0.0
var lost := false
var crafting := false
var result_text := ""
var action_text := ""
var buttons: Array[Dictionary] = []
var quest := false
var won := false
var paused := false
var inventory := false
var dialog := ""
var message := "Repair the old beacon to escape the forest. Talk to Rowan at camp."
var message_time := 8.0
var elapsed := 0.0
var obstacles: Array[Rect2] = []
var trees: Array[Vector2] = []
var items: Array[Dictionary] = []
var npc_home := Vector2(455, 725)
var npc_scout := Vector2(1280, 970)
var npc_position := Vector2(1280, 970)
var gate := Vector2(2030, 280)
var pond := Rect2(920, 350, 330, 230)
var cabin := Rect2(240, 520, 220, 115)
var font: Font
var art: Array[Texture2D] = []
var resource_art: Array[Texture2D] = []
var pond_art: Array[Texture2D] = []
var variant_art: Array[Texture2D] = []
var equipment_art: Array[Texture2D] = []
var blend_art: Array[Texture2D] = []
var pools: Array[Rect2] = []
var pond_colliders: Array[PackedVector2Array] = []
var shrubs: Array[Vector2] = []
var show_collision := false
var foot_anchors: Dictionary = {}
var tree_styles: Dictionary = {}
var meadow: Texture2D
var ground_details: Array[Dictionary] = []
var moving := false
var walk_distance := 0.0
const Geometry = preload("res://world_geometry.gd")
const GroundPainter = preload("res://ground_painter.gd")
const PaintDensity = preload("res://paint_density.gd")
const DepthLayers = preload("res://depth_layers.gd")
var depth_layers = DepthLayers.new()
var pond_paint_layers: Array[Dictionary] = []
var paint_density = PaintDensity.new()
const NAV_CELL := 12.0
var ground_layer: Variant
var collision_profiles: Dictionary = {}
var solid_bodies: Array[Dictionary] = []
var body_lookup: Dictionary = {}
var model_images: Dictionary = {}
var wildlife: Variant
var animal_atlases: Dictionary = {}
var animal_metadata: Dictionary = {}
const AnimalGait=preload("res://animal_gait.gd")
var torch_lit := false
var torch_fuel := 0.0
var torch_uid := -1
var lighting = preload("res://world_lighting.gd").new()
var npc_roaming = preload("res://npc_roaming.gd").new()
var mobile = preload("res://mobile_controls.gd").new()
var mobile_ui = preload("res://mobile_ui.gd").new()
var browser_suspended := false
var browser_callback: JavaScriptObject
var menu_finger := -1
var touch_drag_origin := Vector2.ZERO
var touch_drag_moved := false
var last_mobile_modal := false
# After a menu or conversation closes, held E/Space/click must be released first,
# otherwise the same key press reopens the conversation on the next frame.
var input_latched := false
var mobile_screen:=Vector2.ZERO


const Data=preload("res://item_data.gd")
var bag=preload("res://inventory.gd").new()
var hotbar:Array[int]=[-1,-1,-1,-1,-1,-1]
var active_hotbar:int=0
var selected_slot:int=-1
var drag_slot:int=-1
var crafting_station:int=-1
var crafting_page:int=0
var tree_states:Dictionary={}
var workbenches:Array[Dictionary]=[]
var ore_veins:Array[Dictionary]=[]
var next_bench_uid:int=2
var npc_states:Dictionary={}
var nav_grid:AStarGrid2D
var nav_revision:int=0
var action:Dictionary={}
var interaction_cooldown:float=0.0
var harvest_effects:Array[Dictionary]=[]
var utility_icons:Array[Texture2D]=[]
var utility_props:Array[Texture2D]=[]
var npc_atlases:Dictionary={}
var rowan_lantern:Texture2D
var avatar_use:Texture2D
var use_weapon_art:Texture2D
var use_weapon_index:int=-1
var use_metadata:Dictionary={}
const USE_CELL=Vector2(192,192)*ATLAS_PIXEL_SCALE
const USE_ANCHOR=Vector2(96,166)*ATLAS_PIXEL_SCALE
const NPC_ANGLES=[0,45,90,135,180,225,270,315]
const CAMP=Vector2(455,725)
const WALK_STRIDE := 60.48 # Side-view support-foot travel (1.8) * pose scale (42) * sprite scale (0.8)


func visible_bounds(part: Image) -> Rect2i:
	# Fit to visible paint, not nearly transparent color padding from the atlas.
	# Preserve original pixels and feathered edges inside a six-pixel safety margin.
	part.convert(Image.FORMAT_RGBA8)
	var bytes := part.get_data()
	var width := part.get_width()
	var height := part.get_height()
	var left := width
	var top := height
	var right := -1
	var bottom := -1
	for y in range(0, height, 2):
		for x in range(0, width, 2):
			if bytes[(y * width + x) * 4 + 3] >= 32:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < 0: return Rect2i(0, 0, width, height)
	left = maxi(0, left - 6)
	top = maxi(0, top - 6)
	right = mini(width, right + 8)
	bottom = mini(height, bottom + 8)
	return Rect2i(left, top, right - left, bottom - top)

func load_grid(path: String, columns: int, rows: int, row_cuts: Array = [], column_cuts: Array = []) -> Array[Texture2D]:
	var sheet := Image.load_from_file(path)
	var textures: Array[Texture2D] = []
	for row in range(rows):
		for col in range(columns):
			var x := int(float(col) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col])
			var y := int(float(row) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row]) * sheet.get_height())
			var right := int(float(col + 1) * sheet.get_width() / columns) if column_cuts.is_empty() else int(column_cuts[row][col + 1])
			var bottom := int(float(row + 1) * sheet.get_height() / rows) if row_cuts.is_empty() else int(float(row_cuts[row + 1]) * sheet.get_height())
			var part := sheet.get_region(Rect2i(x, y, right - x, bottom - y))
			var cropped: Image = part.get_region(visible_bounds(part))
			cropped.fix_alpha_edges()
			cropped.generate_mipmaps()
			textures.append(ImageTexture.create_from_image(cropped))
	return textures

func auto_grid(path: String, columns: int, rows: int) -> Array[Texture2D]:
	var sheet := Image.load_from_file(path)
	sheet.convert(Image.FORMAT_RGBA8)
	var data := sheet.get_data()
	var width := sheet.get_width()
	var height := sheet.get_height()
	var ys: Array = [0.0]
	for row in range(1, rows):
		var expected := int(float(row) * height / rows)
		var radius := int(float(height) / rows * 0.40)
		var best := expected
		var score := INF
		for y in range(maxi(1, expected - radius), mini(height - 1, expected + radius)):
			var occupied := 0
			for x in range(0, width, 2):
				if data[(y * width + x) * 4 + 3] > 100: occupied += 1
			var cost := occupied + absf(y - expected) * 0.001
			if cost < score: score = cost; best = y
		ys.append(float(best) / height)
	ys.append(1.0)
	var xs: Array = []
	for row in range(rows):
		var cuts: Array = [0]
		for col in range(1, columns):
			var expected := int(float(col) * width / columns)
			var radius := int(float(width) / columns * 0.40)
			var best := expected
			var score := INF
			for x in range(maxi(1, expected - radius), mini(width - 1, expected + radius)):
				var occupied := 0
				for y in range(int(ys[row] * height), int(ys[row + 1] * height), 2):
					if data[(y * width + x) * 4 + 3] > 100: occupied += 1
				var cost := occupied + absf(x - expected) * 0.001
				if cost < score: score = cost; best = x
			cuts.append(best)
		cuts.append(width)
		xs.append(cuts)
	return load_grid(path, columns, rows, ys, xs)

func load_texture(path: String) -> Texture2D:
	var image: Image = Image.load_from_file(path)
	image.fix_alpha_edges()
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func held_weapon_texture(index: int) -> Texture2D:
	# High-resolution atlases stay full quality; keep only the currently held
	# normal tool resident instead of uploading all nine large sheets at startup.
	if index < 0 or index >= held_weapon_art.size(): return null
	if held_weapon_art[index] == null:
		held_weapon_art.fill(null)
		held_weapon_art[index] = load_texture("res://assets/held-weapon-%d.png" % index)
	return held_weapon_art[index]

func load_art() -> void:
	collision_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://collision_profiles.json"))
	beacon.load_art(self)
	art = load_grid("res://assets/environment.png", 3, 2, [0.0, 552.0/1024, 1.0], [[0,520,1024,1536],[0,499,1024,1536]])
	resource_art = load_grid("res://assets/materials.png", 3, 3, [0.0, 0.36, 0.67, 1.0])
	pond_art = load_grid("res://assets/ponds.png", 3, 1, [], [[0,607,1208,1774]])
	variant_art = load_grid("res://assets/tree-variants.png", 3, 2, [0.0, 624.0/1024, 1.0], [[0,512,1024,1536],[0,516,1024,1536]])
	equipment_art = load_grid("res://assets/equipment.png", 4, 2)
	blend_art = load_grid("res://assets/ground-blends.png", 3, 2, [], [[0,512,1024,1536],[0,522,1024,1536]])
	harvest_art = auto_grid("res://assets/harvest-nodes.png", 3, 6)
	prop_art = auto_grid("res://assets/cabin-props.png", 3, 2)
	status_art = auto_grid("res://assets/status-icons.png", 2, 1)
	utility_icons = load_grid("res://assets/utility-icons.png", 3, 3)
	utility_props = load_grid("res://assets/utility-props.png", 3, 2)
	avatar_unarmed = load_texture("res://assets/traveler-unarmed-directions.png")
	# Full-quality armed/action sheets load when first used, not at startup.
	use_metadata = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tool-use-meta.json"))
	npc_atlases = {"Rowan": load_texture("res://assets/npc-rowan-directions.png"), "Ash": load_texture("res://assets/npc-ash-directions.png")}
	rowan_lantern = load_texture("res://assets/npc-rowan-lantern.png")
	load_animal_art()
	held_weapon_art.clear()
	for index in range(9): held_weapon_art.append(null)
	for texture in art + variant_art + harvest_art + prop_art + utility_props + beacon.model_textures():
		var pixels: Image = texture.get_image()
		model_images[texture] = pixels
		var sole_y: int = pixels.get_height() - 1
		for y in range(pixels.get_height() - 1, -1, -1):
			var solid := false
			for x in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a > 0.5:
					solid = true
					break
			if solid:
				sole_y = y
				break
		var total := 0.0
		var weighted_x := 0.0
		for y in range(maxi(0, sole_y - int(pixels.get_height() * 0.08)), sole_y + 1):
			for x in range(pixels.get_width()):
				var alpha: float = pixels.get_pixel(x, y).a
				if alpha > 0.5:
					total += alpha
					weighted_x += (x + 0.5) * alpha
		foot_anchors[texture] = Vector2(weighted_x / total if total > 0 else pixels.get_width() * 0.5, sole_y + 1)
	meadow = ImageTexture.create_from_image(Image.load_from_file("res://assets/meadow.png"))
	ground_details.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 15015
	for i in range(65):
		var position := Vector2(rng.randf_range(70, 2120), rng.randf_range(90, 1420))
		if absf(position.y - 760) < 90 or absf(position.x - 1700) < 85: continue
		ground_details.append({"p": position, "size": Vector2(rng.randf_range(70, 130), rng.randf_range(35, 65)), "variant": i % 2})

func ground_patch(index: int, center: Vector2, size: Vector2, opacity: float = 1.0) -> void:
	if not blend_art.is_empty():
		draw_texture_rect(paint_density.prepare_rect(blend_art[index], size), Rect2(center - size * 0.5, size), false, Color(1, 1, 1, opacity))

func load_animal_art() -> void:
	animal_atlases.clear()
	animal_metadata.clear()
	var path := "res://assets/animal_atlas.json"
	if not FileAccess.file_exists(path): return
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	animal_metadata = metadata.get("species", {})
	for species in animal_metadata:
		animal_atlases[species] = load_texture(str(animal_metadata[species].path))

func update_wildlife(dt: float) -> void:
	if wildlife == null: return
	var enabled: bool = active_exploration() and not paused and not inventory and not crafting and dialog.is_empty()
	wildlife.update(self, dt, wildlife_period(), enabled)

func wildlife_damage(amount: float, species: String) -> float:
	if not active_exploration() or paused or inventory or crafting or not dialog.is_empty(): return 0.0
	if bag.count("crystal") > 0:
		bag.remove("crystal", 1)
		sanitize_hotbar()
		notify("A magic stone blocked the " + species + " attack.")
		return 0.0
	take_damage(amount)
	notify("The " + species + " hit you. Move away during its warning!")
	return amount

func model_spec(kind: String, p: Vector2, index: int = -1) -> Dictionary:
	# The object identity never includes its hit animation or camera position.
	match kind:
		"tree":
			if not tree_live(p):
				var stump: int = absi(int(p.x + p.y)) % 2
				return {"texture": utility_props[1 + stump], "foot": p + Vector2(0, 4), "height": 46.0, "profile": "stump_%d" % stump, "mirror": false}
			var seed_value: int = absi(int(p.x * 17 + p.y * 31))
			var variant: int = int(tree_styles.get(p, seed_value % 6))
			var warmth: float = float(seed_value % 11) / 180.0
			return {"texture": art[variant] if variant < 3 else variant_art[variant - 3], "foot": p + Vector2(0, 5), "height": 148.0 + seed_value % 39, "profile": "tree_%d" % variant, "mirror": seed_value % 2 != 0, "tint": Color(1.0 - warmth * 0.35, 1.0 - warmth * 0.15, 1.0 - warmth)}
		"shrub":
			var variant: int = absi(int(p.x + p.y)) % 4
			return {"texture": art[3] if variant == 0 else variant_art[variant + 2], "foot": p + Vector2(0, 9), "height": 53.0 + absi(int(p.x)) % 13, "profile": "shrub_%d" % variant, "mirror": false}
		"resource":
			var item: Dictionary = items[index]
			if item.get("dropped", false): return {}
			var row: int = 0 if item.kind in ["branch", "berry"] else (1 if item.kind == "rock" else 2)
			var variant: int = int(item.variant)
			var height: float = 30.0 if row == 1 else 38.0
			if item.taken: height *= 0.48
			var type_name: String = ["branch", "rock", "rope"][row]
			return {"texture": harvest_art[row * 3 + variant + (9 if item.taken else 0)], "foot": p + Vector2(0, 4), "height": height, "profile": "resource_%s%s_%d" % [type_name, "_spent" if item.taken else "", variant], "mirror": bool(item.get("mirror", false))}
		"prop":
			var prop: Dictionary = props[index]
			return {"texture": prop_art[int(prop.sprite)], "foot": p, "height": float(prop.height), "profile": "prop_%d" % int(prop.sprite), "mirror": false}
		"cabin": return {"texture": prop_art[0], "foot": p, "height": 222.0, "profile": "cabin", "mirror": false}
		"gate": return {"texture": art[5], "foot": p, "height": 132.0, "profile": "gate", "mirror": false}
		"bench": return {"texture": utility_props[0], "foot": p + Vector2(0, 8), "height": 82.0, "profile": "bench", "mirror": false}
		"beacon", "rune_rock", "shrine": return beacon.model_spec(kind)
		"ore":
			var vein: Dictionary = ore_veins[index]
			var variant: int = int(vein.variant) % 3
			return {"texture": utility_props[3 + variant], "foot": p, "height": 40.0 if vein.depleted else 62.0, "profile": "ore_%d" % variant, "mirror": false}
	return {}

func model_polygons(spec: Dictionary) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if spec.is_empty(): return polygons
	var profile_key: String = str(spec.profile)
	if not collision_profiles.has(profile_key):
		push_error("Missing contour: " + profile_key)
		return polygons
	var rect: Rect2 = sprite_rect(spec.texture, spec.foot, float(spec.height))
	for raw in collision_profiles[profile_key].polygons:
		var polygon := PackedVector2Array()
		for pair in raw:
			var point: Vector2 = rect.position + Vector2(float(pair[0]), float(pair[1])) * rect.size
			if bool(spec.mirror): point.x = float(spec.foot.x) * 2.0 - point.x
			polygon.append(point)
		polygons.append(polygon)
	return polygons

func model_depth(spec: Dictionary) -> float:
	var rect: Rect2 = sprite_rect(spec.texture, spec.foot, float(spec.height))
	return rect.position.y + float(collision_profiles[spec.profile].depth_v) * rect.size.y

func paint_model(spec: Dictionary, tint: Color = Color.WHITE, sway: float = 0.0) -> void:
	draw_set_transform(-camera + spec.foot, sway, Vector2(-1 if bool(spec.mirror) else 1, 1))
	draw_sprite(spec.texture, Vector2.ZERO, float(spec.height), tint)
	draw_set_transform(-camera)

func varied_tree(p: Vector2, faded: bool, sway: float = 0.0) -> void:
	var spec: Dictionary = model_spec("tree", p)
	var tint: Color = spec.get("tint", Color.WHITE)
	# Sway around the original root. Variant, scale, mirror and colour stay fixed.
	# Only elevated paint fades; the solid root remains opaque and grounded.
	var profile: Dictionary = collision_profiles[spec.profile]
	var rect: Rect2 = sprite_rect(spec.texture, Vector2.ZERO, float(spec.height))
	var texture: Texture2D = paint_density.prepare_rect(spec.texture, rect.size)
	var cut: int = clampi(roundi(float(profile.get("overhead_split_v", 0.75)) * texture.get_height()), 0, texture.get_height())
	draw_set_transform(-camera + spec.foot, sway, Vector2(-1 if bool(spec.mirror) else 1, 1))
	for portion in [Rect2(0, 0, texture.get_width(), cut), Rect2(0, cut, texture.get_width(), texture.get_height() - cut)]:
		if portion.size.y <= 0: continue
		var destination := Rect2(rect.position + portion.position / Vector2(texture.get_width(), texture.get_height()) * rect.size, portion.size / Vector2(texture.get_width(), texture.get_height()) * rect.size)
		var color := tint
		if portion.position.y == 0 and faded: color.a = 0.42
		draw_texture_rect_region(texture, destination, portion, color)
	draw_set_transform(-camera)

func sprite_rect(tex: Texture2D, foot: Vector2, height: float) -> Rect2:
	var scale := height / tex.get_height()
	var width := tex.get_width() * scale
	var pivot: Vector2 = foot_anchors.get(tex, Vector2(tex.get_width() * 0.5, tex.get_height()))
	return Rect2(foot - pivot * scale, Vector2(width, height))

func draw_sprite(tex: Texture2D, foot: Vector2, height: float, tint: Color = Color.WHITE) -> void:
	var rect: Rect2 = sprite_rect(tex, foot, height)
	draw_texture_rect(paint_density.prepare_rect(tex, rect.size), rect, false, tint)

func painted_sprite(index: int, foot: Vector2, height: float, _flip: bool = false, tint: Color = Color.WHITE) -> void:
	if not art.is_empty(): draw_sprite(art[index], foot, height, tint)

func direction_index(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y): return 1 if direction.x < 0 else 2
	return 3 if direction.y < 0 else 0

func feet_rect(p: Vector2) -> Rect2:
	return Geometry.polygon_bounds(feet_polygon(p))

func feet_polygon(p: Vector2) -> PackedVector2Array:
	return Geometry.capsule_polygon(p + Vector2(0, -1), 14.0, 7.0, 8)

func rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])

func paper_panel(rect: Rect2, fill: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = Color("a68e62")
	style.shadow_color = Color(0.02, 0.08, 0.09, 0.18)
	style.shadow_size = 4
	draw_style_box(style, rect)


func _ready() -> void:
	font = ThemeDB.fallback_font
	setup_mobile()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	load_art()
	ground_layer = GroundPainter.new()
	add_child(ground_layer)
	ground_layer.setup(paint_density.prepare_rect(meadow, WORLD), WORLD)
	build_world()
	map_view.setup(WORLD)
	map_view.reveal(CAMP, 330.0)
	wildlife = load("res://wildlife.gd").new()
	wildlife.setup(self, resource_seed)
	survival.setup(resource_seed)
	update_wildlife(0.0)
	warm_display_art()
	prepare_pond_paint()
	paint_entries() # Prepare cached depth bands before the first interactive frame.
	print("GAME_READY v0.1.7-alpha.1")
	queue_redraw()

func warm_display_art() -> void:
	# Prepare native-resolution display textures before the first frame.
	# Display size never reduces source pixels; geometry keeps original anchors.
	for entry in scenery_entries():
		var spec: Dictionary = model_spec(str(entry.kind), entry.p, int(entry.index))
		if not spec.is_empty():
			paint_density.prepare_rect(spec.texture, sprite_rect(spec.texture, spec.foot, float(spec.height)).size)
	for i in range(pools.size()): paint_density.prepare_rect(pond_art[i], pools[i].size)
	for detail in ground_details: paint_density.prepare_rect(blend_art[int(detail.variant)], detail.size)

func build_world() -> void:
	tree_styles.clear()
	trees.clear()
	items.clear()
	shrubs.clear()
	pond_colliders.clear()
	pools = [pond, Rect2(550, 1080, 220, 150), Rect2(1380, 380, 210, 135)]
	props = [{"p": Vector2(512, 649), "sprite": 1, "height": 49.0}, {"p": Vector2(229,630), "sprite": 3, "height": 46.0}, {"p": Vector2(265,666), "sprite": 4, "height": 34.0}]
	rebuild_obstacles()
	beacon.setup(self)
	# Keep the main east/west and north/south paths clear.
	var rng := RandomNumberGenerator.new()
	rng.seed = 10200
	for i in range(115):
		var p := Vector2(rng.randf_range(90, 2110), rng.randf_range(100, 1400))
		if absf(p.y - 760) < 105 or absf(p.x - 1700) < 95:
			continue
		if p.distance_to(player) < 270 or p.distance_to(npc_home) < 180:
			continue
		if p.distance_to(gate) < 210 or p.distance_to(npc_scout) < 170:
			continue
		if quest_site_near(p, 125.0) or quest_site_near(p + Vector2(65, 24), 95.0):
			continue
		var by_water := false
		for pool in pools:
			if pool.grow(80).has_point(p): by_water = true
		if by_water or cabin.grow(95).has_point(p): continue
		var usage := [0, 0, 0, 0, 0, 0]
		for neighbor in trees:
			if neighbor.distance_to(p) < 280:
				usage[int(tree_styles[neighbor])] += 1
		var variant := i % 6
		for k in range(6):
			var candidate := (i + k) % 6
			if usage[candidate] < usage[variant]: variant = candidate
		tree_styles[p] = variant
		trees.append(p)
		if i % 4 == 0:
			var shrub := p + Vector2(65, 24)
			shrubs.append(shrub)
	rebuild_obstacles()
	var supplies := RandomNumberGenerator.new()
	if resource_seed == 0: supplies.randomize()
	else: supplies.seed = resource_seed
	spawn_resources(supplies, "branch", 22, 5)
	spawn_resources(supplies, "rock", 18, 4)
	spawn_resources(supplies, "rope", 18, 4)
	spawn_resources(supplies, "berry", 9, 2)
	setup_features_world()

func quest_site_near(p: Vector2, radius: float) -> bool:
	for kind in beacon.kinds():
		if p.distance_to(beacon.position(kind)) < radius: return true
	return false

func tree_distance(p: Vector2) -> float:
	var distance := 99999.0
	for tree in trees: distance = minf(distance, p.distance_to(tree))
	return distance

func forest_density(p: Vector2) -> int:
	var density := 0
	for tree in trees:
		if tree.distance_to(p) < 190: density += 1
	return density

func near_path(p: Vector2) -> bool:
	return absf(p.y - 760) < 78 or absf(p.x - 1700) < 78

const RESOURCE_ZONES := Vector2i(3, 3)
const ORE_REGIONS := [Vector2(820,610),Vector2(1440,620),Vector2(660,1040),Vector2(1900,1150)]

func resource_zone(p: Vector2) -> int:
	var cell := Vector2i(clampi(int(p.x / WORLD.x * RESOURCE_ZONES.x), 0, RESOURCE_ZONES.x - 1), clampi(int(p.y / WORLD.y * RESOURCE_ZONES.y), 0, RESOURCE_ZONES.y - 1))
	return cell.y * RESOURCE_ZONES.x + cell.x

func zone_rect(zone: int) -> Rect2:
	var size := WORLD / Vector2(RESOURCE_ZONES)
	return Rect2(Vector2(zone % RESOURCE_ZONES.x, zone / RESOURCE_ZONES.x) * size, size)

func resource_candidate(rng: RandomNumberGenerator, kind: String, zone: Rect2, zone_trees: Array) -> Vector2:
	# Ecological placement inside one map zone: wood and berries beside trees,
	# rocks mostly around the ore outcrops, fibers in open meadow.
	if kind == "branch" or kind == "berry":
		if zone_trees.is_empty(): return Vector2.INF
		var tree: Vector2 = zone_trees[rng.randi_range(0, zone_trees.size() - 1)]
		return tree + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(47, 116)
	if kind == "rock":
		var near_ore: Array = ORE_REGIONS.filter(func(o): return zone.grow(120).has_point(o))
		if not near_ore.is_empty() and rng.randf() < 0.75:
			return near_ore[rng.randi_range(0, near_ore.size() - 1)] + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(45, 215)
	var p := zone.position + Vector2(rng.randf(), rng.randf()) * zone.size
	if kind == "rope" and (tree_distance(p) < 92 or forest_density(p) >= 3): return Vector2.INF
	if kind == "rock" and tree_distance(p) < 70: return Vector2.INF
	return p

func resource_spot_clear(p: Vector2, rng: RandomNumberGenerator) -> bool:
	if not Rect2(Vector2(90, 120), WORLD - Vector2(180, 230)).has_point(p): return false
	if p.distance_to(Vector2(360,760)) < 75 or quest_site_near(p, 90.0): return false
	if near_path(p) and rng.randf() < 0.88: return false
	if not walkable(p) or not walkable(p + Vector2(0,30)): return false
	if p.distance_to(npc_home) < 75 or p.distance_to(npc_scout) < 120 or cabin.grow(28).has_point(p): return false
	# Never grow a node under someone standing there (daily regrowth).
	for actor in [player, npc_home, npc_position]:
		if p.distance_to(actor) < 60: return false
	if wildlife != null:
		for animal in wildlife.animals:
			if p.distance_to(animal.p) < 70: return false
	for item in items:
		if not item.taken and item.pos.distance_to(p) < 68: return false
	return true

func spawn_resources(rng: RandomNumberGenerator, kind: String, count: int, camp_start: int = 0) -> int:
	# Balanced placement: each new node goes to the map zone that currently has
	# the fewest of this kind, so supplies never pile up in one corner.
	var zones: int = RESOURCE_ZONES.x * RESOURCE_ZONES.y
	var per_zone: Array[int] = []
	per_zone.resize(zones); per_zone.fill(0)
	for item in items:
		if item.kind == kind and not item.taken and not item.get("dropped", false): per_zone[resource_zone(item.pos)] += 1
	var exhausted: Array[bool] = []
	exhausted.resize(zones); exhausted.fill(false)
	var zone_trees: Array = []
	for z in range(zones):
		var rect := zone_rect(z)
		zone_trees.append(trees.filter(func(t): return rect.has_point(t)))
	var placed := 0
	while placed < count:
		var p := Vector2.INF
		if placed < camp_start:
			# A few first-day supplies near camp so a new run can start crafting.
			for attempt in range(400):
				var c: Vector2 = Vector2(550,800) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(90, 480)
				var z := resource_zone(c)
				var candidate := resource_candidate(rng, kind, zone_rect(z), (zone_trees[z] as Array).filter(func(t): return t.distance_to(Vector2(550,800)) < 560))
				if candidate != Vector2.INF and candidate.distance_to(Vector2(550,800)) < 540 and resource_spot_clear(candidate, rng): p = candidate; break
		else:
			var best := -1
			# Seeded tie-break keeps a run reproducible for a given resource_seed.
			var offset := rng.randi_range(0, zones - 1)
			for k in range(zones):
				var z: int = (k + offset) % zones
				if exhausted[z]: continue
				if best < 0 or per_zone[z] < per_zone[best]: best = z
			if best < 0: break
			for attempt in range(160):
				var candidate := resource_candidate(rng, kind, zone_rect(best), zone_trees[best])
				if candidate != Vector2.INF and resource_zone(candidate) == best and resource_spot_clear(candidate, rng): p = candidate; break
			if p == Vector2.INF:
				exhausted[best] = true
				continue
		if p == Vector2.INF: camp_start = 0; continue
		add_item(p,kind)
		items[-1]["variant"] = rng.randi_range(0,2)
		items[-1]["mirror"] = rng.randf() < 0.5
		per_zone[resource_zone(p)] += 1
		placed += 1
	if placed < count: push_warning("Resource placement below target: " + kind)
	return placed

func resource_rect(item: Dictionary) -> Rect2:
	return Rect2(item.pos - Vector2(13,10),Vector2(26,15))


func add_item(p: Vector2, kind: String) -> void:
	items.append({"pos": p, "kind": kind, "taken": false, "variant": items.size() % 3, "mirror": false})

func walkable(p:Vector2)->bool:
	if not static_walkable(p):return false
	if wildlife != null and wildlife.body_blocked(p): return false
	for npc in [npc_home,npc_position]:
		if Geometry.polygons_overlap(feet_polygon(p), feet_polygon(npc)):return false
	return true

func update_stamina(direction: Vector2, dt: float) -> void:
	var wants: bool = (Input.is_physical_key_pressed(KEY_SHIFT) or mobile_sprint) and direction.length() > 0.2
	sprinting = wants and not stamina_exhausted and stamina > 0.0
	if sprinting:
		if mobile_sprint: mobile_sprint_used = true
		stamina = maxf(0.0, stamina - Balance.STAMINA_DRAIN * dt)
		stamina_rest = 0.0
		if stamina <= 0.0:
			stamina_exhausted = true; sprinting = false; mobile_sprint = false
			notify("Out of breath. Wait for your stamina to recover.")
	else:
		if direction.length() <= 0.2 and mobile_sprint_used: mobile_sprint = false; mobile_sprint_used = false
		stamina_rest += dt
		if stamina_rest >= Balance.STAMINA_REGEN_DELAY:
			stamina = minf(Balance.STAMINA_MAX, stamina + Balance.STAMINA_REGEN * dt)
		if stamina_exhausted and stamina >= Balance.STAMINA_RECOVER: stamina_exhausted = false

func draw_stamina() -> void:
	# A small bar above the traveler, only while stamina is in use.
	if stamina >= Balance.STAMINA_MAX and not sprinting: return
	var rect := Rect2(player + Vector2(-30, -120), Vector2(60, 6))
	draw_rect(rect.grow(1.5), Color(0.12, 0.16, 0.13, 0.75))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * stamina / Balance.STAMINA_MAX, rect.size.y)), Color("c9824a") if stamina_exhausted else Color("9fc27a"))

func move_player(direction: Vector2, delta: float, speed_scale: float = 1.0) -> void:
	if direction.length() > 0:
		var target_angle := atan2(direction.x,direction.y)
		var current_angle := atan2(facing.x,facing.y)
		var angle := lerp_angle(current_angle,target_angle,1.0-exp(-maxf(0,delta)*18.0))
		facing = Vector2(sin(angle),cos(angle))
	var movement := direction.limit_length() * SPEED * speed_scale * Balance.movement_scale(fullness) * delta
	# Small steps prevent crossing a thin trunk even during a long frame.
	var steps := maxi(1, ceili(movement.length() / 1.5))
	var step := movement / steps
	for i in range(steps):
		var next := player + Vector2(step.x, 0)
		if walkable(next): player.x = next.x
		next = player + Vector2(0, step.y)
		if walkable(next): player.y = next.y

func update_walk(distance: float) -> void:
	moving = distance > 0.1
	if moving: walk_distance = fposmod(walk_distance + distance, WALK_STRIDE)

func press_feedback(id: String) -> void:
	press_fx[id] = PRESS_TIME

func press_scale(id: String) -> float:
	var t: float = clampf(float(press_fx.get(id, 0.0)) / PRESS_TIME, 0.0, 1.0)
	if t <= 0.0: return 1.0
	# Squash to 86 %, then a small overshoot on the way back to full size.
	return 1.0 - 0.14 * t + 0.05 * sin((1.0 - t) * PI) * t

func pressed_rect(rect: Rect2, id: String, held: bool = false) -> Rect2:
	var scale: float = press_scale(id) * (0.93 if held else 1.0)
	if is_equal_approx(scale, 1.0): return rect
	return Rect2(rect.get_center() - rect.size * scale * 0.5, rect.size * scale)

func update_press_feedback(delta: float) -> void:
	for id in press_fx.keys():
		press_fx[id] = float(press_fx[id]) - delta
		if float(press_fx[id]) <= 0.0: press_fx.erase(id)
	if active_hotbar != feedback_hotbar:
		feedback_hotbar = active_hotbar
		press_feedback("select_" + str(active_hotbar))

func _process(delta:float)->void:
	moving=false
	update_press_feedback(maxf(0.0, delta))
	var dt:float=minf(maxf(0,delta),0.05)
	# Menus suspend the complete simulation, including the survival clock and AI.
	# Time cannot pass safely in a backpack while predators are frozen.
	var modal:bool=inventory or crafting or not dialog.is_empty()
	if map_open and (modal or paused or not active_exploration()):map_open=false
	var blocked:bool= browser_suspended or (mobile.enabled and get_viewport_rect().size.x < get_viewport_rect().size.y)
	if modal != last_mobile_modal:
		mobile.clear(); last_mobile_modal=modal
		if not modal: input_latched=true
	if not paused and not modal and not blocked and active_exploration():
		elapsed+=dt;message_time=maxf(0,message_time-dt)
		advance_vitals(dt)
		update_torch(dt)
		if phase=="day":advance_day(dt)
		elif phase=="dusk" or phase=="night":advance_phase(dt)
		if active_exploration():
			update_action(dt);update_npcs(dt);sanitize_hotbar()
			var direction:Vector2=Vector2.ZERO
			if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):direction.x-=1
			if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):direction.x+=1
			if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):direction.y-=1
			if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):direction.y+=1
			direction += mobile.direction()
			if direction.length()>0:cancel_action()
			var previous:Vector2=player
			update_stamina(direction,dt)
			map_view.reveal(player)
			move_player(direction,dt,Balance.SPRINT_MULTIPLIER if sprinting else 1.0);update_walk(player.distance_to(previous))
			if input_latched and not held_action_input():input_latched=false
			if action.is_empty() and interaction_cooldown<=0 and not input_latched:
				if Input.is_physical_key_pressed(KEY_E) or mobile.interact_held:interact()
				elif ((not mobile.enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or Input.is_physical_key_pressed(KEY_SPACE) or mobile.use_held) and selected_item().get("id","")!="torch":use_selected()
			update_wildlife(dt)
			survival.update(self,dt)
			beacon.update(self,dt)
	beacon_glow=beacon.glow()
	var screen:Vector2=get_viewport_rect().size
	if mobile.enabled and screen!=mobile_screen:
		mobile_screen=screen
		clear_mobile_input()
		if OS.has_feature("web"):mobile.css_height=float(JavaScriptBridge.eval("document.getElementById('canvas').clientHeight || innerHeight"))
	camera=player-screen*Vector2(0.5,0.67)
	camera.x=clampf(camera.x,0,maxf(0,WORLD.x-screen.x));camera.y=clampf(camera.y,0,maxf(0,WORLD.y-screen.y))
	ground_layer.position = -camera
	queue_redraw()

func held_action_input()->bool:
	return Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or mobile.interact_held or mobile.use_held

func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode
	if key==KEY_F3 and OS.is_debug_build():show_collision=not show_collision;return
	if key==KEY_R and (won or lost):get_tree().reload_current_scene();return
	if key==KEY_M and active_exploration() and not paused and dialog.is_empty() and not inventory and not crafting:
		map_open=not map_open;return
	if key==KEY_ESCAPE:
		cancel_action()
		if map_open:map_open=false
		elif not dialog.is_empty():dialog=""
		elif inventory:inventory=false;drag_slot=-1
		elif crafting:crafting=false;crafting_station=-1
		elif not won and not lost:paused=not paused
		return
	if paused or won or lost:return
	if phase=="result":
		if key==KEY_ENTER or key==KEY_SPACE:next_day()
		return
	if not active_exploration():return
	if not dialog.is_empty():
		if key==KEY_E or key==KEY_SPACE:dialog=""
		return
	if key==KEY_H:use_medicine();return
	if key==KEY_B:
		inventory=not inventory;crafting=false;cancel_action();return
	if crafting:
		if key==KEY_C:crafting=false;crafting_station=-1
		elif key>=KEY_1 and key<=KEY_6:
			var recipes:Array[int]=visible_recipes()
			var i:int=crafting_page*6+key-KEY_1
			if i<recipes.size():press_feedback("craft_"+str(recipes[i]));craft_recipe(recipes[i])
		return
	if key>=KEY_1 and key<=KEY_6:
		var slot:int=key-KEY_1
		if inventory and selected_slot>=0 and not bag.slots[selected_slot].is_empty():
			bind_hotbar(int(bag.slots[selected_slot].uid),slot)
		else:active_hotbar=slot;cancel_action()
		return
	if inventory:return
	if key==KEY_T:toggle_torch();return
	if key==KEY_E:interact()
	elif key==KEY_SPACE:use_selected()
	elif key==KEY_C:crafting=true;crafting_page=0;crafting_station=nearby_bench();cancel_action()

func notify(text: String) -> void:
	message = text
	message_time = 5.0

func target_line_clear(target_position:Vector2)->bool:
	var direction: Vector2 = (target_position - player).normalized()
	var endpoint: Vector2 = target_position - direction * minf(2.0, player.distance_to(target_position))
	for body in solid_bodies:
		if not body_active(body): continue
		if body.kind != "water" and (body.p.distance_to(target_position) < 0.01 or Geometry.point_in_polygon_or_boundary(target_position, body.polygon)): continue
		if Geometry.segment_intersects_polygon(player, endpoint, body.polygon): return false
	return true

func nearest_target(tools_only:bool=false)->Dictionary:
	var candidates:Array[Dictionary]=[]
	if not tools_only:
		candidates=[{"pos":npc_home,"kind":"guide"},{"pos":npc_position,"kind":"scout"}]
		for bench in workbenches:candidates.append({"pos":bench.p,"kind":"bench","uid":bench.uid})
		for quest in beacon.targets():
			if quest.kind!="rune_rock":candidates.append(quest)
		for i in range(items.size()):
			if not items[i].taken:candidates.append({"pos":items[i].pos,"kind":"item","index":i})
	for p in trees:
		if tree_live(p):candidates.append({"pos":p,"kind":"tree"})
	for i in range(ore_veins.size()):
		if not ore_veins[i].depleted:candidates.append({"pos":ore_veins[i].p,"kind":"ore","index":i})
	if beacon.rune_valid():candidates.append({"pos":beacon.RUNE_POS,"kind":"rune_rock"})
	var item:Dictionary=selected_item()
	if item.get("id","")=="fishing_rod":
		var water:Dictionary=nearest_water()
		if not water.is_empty():candidates.append(water)
	var best:float=88.0;var target:Dictionary={}
	for candidate in candidates:
		var distance:float=player.distance_to(candidate.pos)
		var score:float=distance
		if candidate.kind=="item" and items[int(candidate.index)].get("dropped",false):score*=0.7
		if distance<88 and score<best and target_line_clear(candidate.pos):
			best=score;target=candidate
	return target

func interact()->void:
	if not active_exploration() or paused or inventory or crafting or not dialog.is_empty() or not action.is_empty() or interaction_cooldown>0:return
	var target:Dictionary=nearest_target()
	if target.is_empty():notify("Move closer to a resource, person, workbench or water.");interaction_cooldown=0.3;return
	match target.kind:
		"guide":
			quest=true
			dialog="Rowan - Camp guide\n\nThe only way out is the old beacon by the northern trail.\nIt needs three lost parts: a lens, a gear and an ember core.\nA glint on Stillwater Lake hides the lens. Fish right there.\nA carved rune rock by the southeast ore hides the gear.\nThe core rests on a shrine in the woods west of the lake.\nRepair it with 4 logs + 2 ore, then light it after dark.\nGuard the fire for 60 seconds. Its light draws predators.\n\nGather and craft tools and torches by day. Prepare for night.\nB opens your backpack. Menus pause time and animals."
		"scout":
			if not scout_rewarded:
				scout_rewarded=true
				give_item("fish",2,npc_position+Vector2(24,22))
				give_item("medicine",1,npc_position+Vector2(-24,22))
				give_item("crystal",1,npc_position+Vector2(0,30))
			dialog="Ash - Forest scout\n\nEquip a blade, axe or pickaxe in slots 1-6.\nFace an animal; press Space or click to swing.\nA ! warning means a bite or swipe is coming. Move aside!\n\nWolves tire after pursuit. Use light or break their sight.\nBears warn before charging: step sideways.\nDaylight lasts 120 seconds; survive 90 seconds of night.\nT lights a torch. Red or green eyes mean danger nearby.\nFish restores fullness and sanity. H uses medicine to heal.\nI left supplies for your first visit: fish, medicine and a ward.\n\nLight the old beacon to escape. Menus pause the world."
		"bench":crafting=true;crafting_station=int(target.uid);crafting_page=0
		"beacon":beacon.interact_beacon(self)
		"shrine":beacon.take_core(self)
		"item":collect_item(int(target.index));interaction_cooldown=0.2
		"tree","ore","water","rune_rock":
			if not begin_action(target):interaction_cooldown=0.35

func collect_item(index:int)->void:
	if not active_exploration() or index<0 or index>=items.size() or items[index].taken:return
	var item:Dictionary=items[index]
	if item.kind=="berry":
		var restored:int=mini(22,100-fullness)
		item.taken=true;fullness+=restored;survival.eat(self,2.0*restored/22.0)
		notify("Ate berries. Fullness +%d, sanity +%.1f."%[restored,2.0*restored/22.0])
	else:
		var quantity:int=int(item.get("qty",1))
		var new_uid:int=bag.next_uid
		var added:int=bag.add(item.kind,quantity)
		if added>0 and item.get("dropped",false):
			var restored:Dictionary=bag.item_by_uid(new_uid)
			for property in ["fuel","durability"]:
				if not restored.is_empty() and restored.has(property) and item.has(property) and float(item[property])>=0:restored[property]=item[property]
		item["qty"]=quantity-added
		if int(item.qty)==0:item.taken=true
		notify("Collected "+str(added)+" "+item_name(item.kind)+".") if added>0 else notify("Backpack full. Items stay here; B lets you rearrange or drop a stack.")
	sanitize_hotbar()
	update_navigation_area(item.pos)

func craft_recipe(index:int)->void:
	if not active_exploration() or index<0 or index>=Data.RECIPES.size():return
	var recipe:Dictionary=Data.RECIPES[index]
	if recipe.bench and not bench_available():notify("This recipe needs a nearby workbench. Press E at the camp table.");return
	var result:Dictionary=bag.craft(recipe.cost,recipe.id,str(recipe.get("upgrade","")))
	if result.is_empty():notify("Need materials, the base tool, or a free output slot. Nothing was consumed.");return
	if result.id=="torch":
		torch_uid=int(result.uid);torch_fuel=float(result.fuel);torch_lit=true
		notify("Torch lit: 5 m of light, 120 s of fuel. T puts it out. Your weapon stays equipped.")
	else:
		auto_equip(int(result.uid))
		notify("Crafted "+Data.label(result.id)+". Equipped in slot "+str(active_hotbar+1)+".")

func toggle_torch(uid:int=-1)->void:
	if not active_exploration() or paused or inventory or crafting or not dialog.is_empty():return
	if torch_lit and (uid<0 or uid==torch_uid):
		torch_lit=false;notify("Torch put out. T relights it.");interaction_cooldown=0.25;return
	if uid<0:
		if bag.index_of_uid(torch_uid)>=0:uid=torch_uid
		else:
			var index:int=bag.first("torch")
			if index>=0:uid=int(bag.slots[index].uid)
	var item:Dictionary=bag.item_by_uid(uid)
	if item.get("id","")!="torch" or float(item.get("fuel",0))<=0:
		notify("Craft a torch: C, 2 branches + 2 fibers. T lights it; camp has a lantern.");return
	torch_uid=uid;torch_fuel=float(item.fuel);torch_lit=true;interaction_cooldown=0.25
	notify("Torch lit. About 5 m of light; %d s remaining. T puts it out."%ceili(torch_fuel))

func update_torch(dt:float)->void:
	if not torch_lit:return
	var item:Dictionary=bag.item_by_uid(torch_uid)
	if item.get("id","")!="torch":
		torch_lit=false;torch_uid=-1;torch_fuel=0;return
	if paused or inventory or crafting or not dialog.is_empty() or not active_exploration():return
	torch_fuel=maxf(0,float(item.fuel)-maxf(0,dt));item.fuel=torch_fuel
	if torch_fuel<=0:
		bag.remove_uid(torch_uid);torch_lit=false;torch_uid=-1;sanitize_hotbar()
		notify("Your torch burned out. Craft another with 2 branches + 2 fibers, or return to camp.")

func food_check() -> String:
	if fullness <= 0: return "You are starving! Find food soon."
	if fullness <= 20: return "You are very hungry and uncomfortable."
	if fullness <= 40: return "You are hungry."
	if fullness <= 60: return "You should eat some food soon."
	return "You feel well fed."

func take_damage(amount: float) -> void:
	if won or lost:return
	health = clampf(health - maxf(0, amount), 0, 100)
	if health <= 0:
		lost = true
		phase = "lost"
		inventory=false;crafting=false;dialog="";moving=false;cancel_action()
		result_text = "Your health ran out. Keep your distance, fight with tools and carry medicine."

func simulation_running() -> bool:
	return active_exploration() and not paused and not inventory and not crafting and dialog.is_empty() and not browser_suspended and not (mobile.enabled and get_viewport_rect().size.x < get_viewport_rect().size.y)

func advance_vitals(dt: float) -> void:
	if not simulation_running(): return
	var elapsed_time := maxf(0,dt)
	var until_starving := maxf(0,(fullness-hunger_elapsed)/Balance.HUNGER_PER_SECOND)
	hunger_elapsed += elapsed_time * Balance.HUNGER_PER_SECOND
	var hunger_cost := int(hunger_elapsed + 0.0000001)
	if hunger_cost > 0:
		fullness = maxi(0,fullness-hunger_cost)
		hunger_elapsed = maxf(0,hunger_elapsed-hunger_cost)
	var starving_time := maxf(0,elapsed_time-until_starving)
	if starving_time > 0: take_damage(starving_time*Balance.STARVATION_DAMAGE)

func use_medicine() -> void:
	if not active_exploration() or paused or health >= 100 or bag.count("medicine") <= 0:
		if bag.count("medicine") <= 0: notify("No medicine in your backpack.")
		return
	bag.remove("medicine", 1)
	health = minf(100, health + 40)
	sanitize_hotbar()
	notify("Used medicine. Health +40.")

func advance_day(dt: float) -> void:
	if paused or inventory or crafting or not dialog.is_empty() or phase != "day" or won or lost: return
	day_time = minf(day_time + maxf(0, dt), maxf(1, day_duration))
	if day_time >= maxf(1, day_duration):start_night()

func day_fraction() -> float:
	return clampf(day_time / maxf(1, day_duration), 0, 1)

func clock_text() -> String:
	var remaining:float=day_duration-day_time
	if phase=="dusk":remaining=dusk_duration-phase_time
	elif phase=="night":remaining=night_duration-night_elapsed
	elif phase=="result" or won or lost:remaining=0.0
	var seconds := int(ceil(maxf(0,remaining)))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func active_exploration() -> bool:
	return not won and not lost and phase in ["day", "dusk", "night"]

func wildlife_period() -> String:
	if phase=="dusk":return "dusk"
	if phase=="night":return "night"
	return "day"

func start_night() -> void:
	if phase != "day" or paused or inventory or crafting or not dialog.is_empty() or won or lost:return
	phase = "dusk"
	phase_time = 0.0
	night_elapsed = 0.0
	for npc in npc_states.values():npc.moving=false
	notify("Dusk is falling. C crafts a torch: 2 branches + 2 fibers. T lights it; camp has a lantern.")
	print("DUSK_START ", night)

func advance_phase(dt: float) -> void:
	if paused or inventory or crafting or not dialog.is_empty() or won or lost:return
	var remaining:float=maxf(0,dt)
	if phase=="dusk":
		var step:float=minf(remaining,maxf(0,dusk_duration-phase_time))
		phase_time+=step;remaining-=step
		if phase_time>=maxf(0,dusk_duration):
			phase="night";phase_time=0.0;night_elapsed=0.0
			notify("Night %d: stay alive until dawn. Wolves and bears roam the woods." % night)
			print("NIGHT_START ",night)
	if phase=="night":
		night_elapsed=minf(maxf(1,night_duration),night_elapsed+remaining)
		phase_time=night_elapsed
		if night_elapsed>=maxf(1,night_duration):resolve_night()

func choose_action(_index:int)->void:
	# Compatibility for older UI automation. Night choices were replaced by
	# free exploration and real-time animal combat in v0.1.6-alpha.4.
	return

func resolve_night() -> void:
	# Only a completed real-time night can award survival. No abstract power
	# roll, forced consumable use or automatic off-screen damage occurs.
	if phase!="night" or won or lost or night_elapsed<maxf(1,night_duration) or last_survived_night==night:return
	last_survived_night=night
	survived+=1
	cancel_action();moving=false
	result_text="Dawn has arrived. You survived another night in the forest."
	beacon.on_dawn(self)
	phase="result"
	update_wildlife(0.0) # Synchronize day-only wildlife without moving anything.
	print("NIGHT_SURVIVED ",survived)

func beacon_escape()->void:
	if won or lost:return
	won=true;phase="won"
	inventory=false;crafting=false;dialog="";moving=false;cancel_action()
	result_text="The beacon blazes above the trees and lights the way out of the forest."
	print("BEACON_ESCAPE night=",night)

func next_day()->void:
	if phase!="result" or won or lost:return
	night+=1;day_time=0;night_elapsed=0;phase_time=0;phase="day";cancel_action()
	var remaining:Array[Dictionary]=[]
	var regrow:Dictionary={}
	for index in range(items.size()):
		var item: Dictionary = items[index]
		if item.get("dropped",false):
			if not item.taken:remaining.append(item)
		elif item.taken:
			# Yesterday's spot stays cleared; the node grows back somewhere new.
			regrow[item.kind]=int(regrow.get(item.kind,0))+1
		else:
			item["qty"] = 1
			remaining.append(item)
	items=remaining;rebuild_obstacles()
	var growth := RandomNumberGenerator.new()
	if resource_seed == 0: growth.randomize()
	else: growth.seed = resource_seed * 7919 + night
	for kind in ["branch","rock","rope","berry"]:
		if regrow.has(kind):spawn_resources(growth,kind,int(regrow[kind]))
	rebuild_obstacles();rebuild_navigation()
	update_wildlife(0.0)
	notify("Morning! Gather food and prepare your equipment for night "+str(night)+".")

func regrowth_contact_clear(index: int) -> bool:
	if items[index].kind != "rock": return true
	var spec: Dictionary = model_spec("resource", items[index].pos, index)
	for polygon in model_polygons(spec):
		for actor in [player, npc_home, npc_position]:
			if Geometry.polygons_overlap(polygon, feet_polygon(actor)): return false
		if wildlife != null and wildlife.body_blocked(items[index].pos, -1, polygon): return false
	return true

func item_name(kind:String)->String:
	return "Berries" if kind=="berry" else Data.label(kind)

func drop_material(index:int)->void:
	if index<0 or index>2:return
	var id:String=["branch","rock","rope"][index]
	if bag.remove(id,1):items.append({"pos":player+Vector2(19,12),"kind":id,"qty":1,"taken":false,"dropped":true,"variant":0})

func _input(event:InputEvent)->void:
	if browser_suspended or (mobile.enabled and get_viewport_rect().size.x < get_viewport_rect().size.y): return
	if mobile.enabled and mobile.handle_event(event,self):
		get_viewport().set_input_as_handled();return
	if mobile.enabled and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		if event is InputEventScreenDrag:
			if event.index == menu_finger and event.position.distance_to(touch_drag_origin)>20: touch_drag_moved=true
			return
		if event.pressed:
			if menu_finger>=0:return
			menu_finger=event.index;touch_drag_origin=event.position;touch_drag_moved=false
		elif menu_finger!=event.index:return
		if event.canceled:
			menu_finger=-1;drag_slot=-1;return
		if not event.pressed: menu_finger=-1
		var pointer:=InputEventMouseButton.new()
		pointer.position=event.position;pointer.button_index=MOUSE_BUTTON_LEFT;pointer.pressed=event.pressed
		if not event.pressed and inventory and not touch_drag_moved:
			drag_slot=-1
			return
		event=pointer
	if not event is InputEventMouseButton:return
	if inventory and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and drag_slot>=0:
		var target:int=bag_slot_at(event.position)
		var quick:int=bag_hotbar_at(event.position)
		if target>=0:bag.swap(drag_slot,target);selected_slot=target
		elif quick>=0 and not bag.slots[drag_slot].is_empty():bind_hotbar(int(bag.slots[drag_slot].uid),quick)
		drag_slot=-1;get_viewport().set_input_as_handled();return
	if not event.pressed:return
	if inventory:
		var quick:int=bag_hotbar_at(event.position)
		if mobile.enabled and quick>=0:
			activate_button("assign_"+str(quick));return
		var slot:int=bag_slot_at(event.position)
		if slot>=0:
			selected_slot=slot
			if event.button_index==MOUSE_BUTTON_LEFT:drag_slot=slot
			elif event.button_index==MOUSE_BUTTON_RIGHT and not bag.slots[slot].is_empty():bind_hotbar(int(bag.slots[slot].uid),active_hotbar)
			get_viewport().set_input_as_handled();return
	if event.button_index==MOUSE_BUTTON_LEFT:
		for button in buttons:
			if button.rect.has_point(event.position):
				activate_button(button.id);get_viewport().set_input_as_handled();return
		if not inventory and not crafting and dialog.is_empty() and not paused and not map_open:use_selected()
	elif not inventory and not crafting and active_exploration() and not paused:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:active_hotbar=(active_hotbar+5)%6;cancel_action()
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:active_hotbar=(active_hotbar+1)%6;cancel_action()

func activate_button(id:String)->void:
	press_feedback(id)
	mobile.clear()
	if id=="map_close":map_open=false;return
	if id=="restart" and (won or lost):get_tree().reload_current_scene();return
	if id=="resume":paused=false;return
	if paused:return
	if id=="heal":use_medicine();return
	if id=="close":inventory=false;crafting=false;crafting_station=-1;dialog="";drag_slot=-1;return
	if id.begins_with("action_"):choose_action(int(id.trim_prefix("action_")))
	elif id=="morning":next_day()
	elif id.begins_with("craft_") and crafting:craft_recipe(int(id.trim_prefix("craft_")))
	elif id.begins_with("select_") and not inventory and not crafting:active_hotbar=int(id.trim_prefix("select_"));cancel_action()
	elif id.begins_with("assign_") and inventory and selected_slot>=0 and not bag.slots[selected_slot].is_empty():bind_hotbar(int(bag.slots[selected_slot].uid),int(id.trim_prefix("assign_")))
	elif id=="next_page":crafting_page+=1
	elif id=="previous_page":crafting_page=maxi(0,crafting_page-1)
	elif id=="repair":repair_held()
	elif id=="sort":
		var uid:int=int(bag.slots[selected_slot].get("uid",-1)) if selected_slot>=0 else -1
		bag.sort_items();selected_slot=bag.index_of_uid(uid)
	elif id=="drop_selected" and selected_slot>=0 and not bag.slots[selected_slot].is_empty():
		var item:Dictionary=bag.slots[selected_slot].duplicate(true)
		bag.remove_uid(int(item.uid),int(item.qty))
		items.append({"pos":player+Vector2(22,12),"kind":item.id,"qty":item.qty,"durability":item.get("durability",-1),"fuel":item.get("fuel",-1),"taken":false,"dropped":true,"variant":0})
		if int(item.uid)==torch_uid:torch_lit=false;torch_uid=-1;torch_fuel=0
		sanitize_hotbar()

func label_at(p: Vector2, text: String, size: int = 18, color := Color("35483d")) -> void:
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func avatar_direction(direction: Vector2) -> int:
	var heading := fposmod(rad_to_deg(atan2(direction.x,direction.y)),360.0)
	var best := 0
	var distance := INF
	for index in range(FACING_ANGLES.size()):
		var delta := absf(wrapf(heading-float(FACING_ANGLES[index]),-180,180))
		if delta < distance: distance=delta; best=index
	return best

func avatar_frame() -> int:
	return int(walk_distance / WALK_STRIDE * 8.0) % 8 if moving else 8

func equipped_weapon_index()->int:
	var item:Dictionary=selected_item()
	if item.is_empty() or not bag.usable(int(item.uid)):return -1
	return int(Data.info(item.id).get("mesh",-1))

func draw_traveler(p:Vector2,size_scale:float=1.0)->void:
	var direction:int=avatar_direction(facing)
	var equipped:int=equipped_weapon_index()
	draw_player_torch(p,size_scale,true)
	if not action.is_empty() and equipped>=0:
		if avatar_use == null: avatar_use = load_texture("res://assets/traveler-use-directions.png")
		var source:Rect2=Rect2(Vector2(direction*USE_CELL.x,action_frame()*USE_CELL.y),USE_CELL)
		var rect:Rect2=Rect2(p-USE_ANCHOR*AVATAR_SCALE*size_scale,USE_CELL*AVATAR_SCALE*size_scale)
		draw_texture_rect_region(avatar_use,rect,source)
		if use_weapon_index!=equipped:
			use_weapon_index=equipped;use_weapon_art=load_texture("res://assets/held-use-weapon-%d.png"%equipped)
		draw_texture_rect_region(use_weapon_art,rect,source)
	else:
		if equipped>=0 and avatar_armed == null: avatar_armed=load_texture("res://assets/traveler-armed-directions.png")
		var texture:Texture2D=avatar_armed if equipped>=0 else avatar_unarmed
		var source:Rect2=Rect2(Vector2(direction*AVATAR_CELL.x,avatar_frame()*AVATAR_CELL.y),AVATAR_CELL)
		var rect:Rect2=Rect2(p-AVATAR_ANCHOR*AVATAR_SCALE*size_scale,AVATAR_CELL*AVATAR_SCALE*size_scale)
		draw_texture_rect_region(texture,rect,source)
		if equipped>=0:draw_texture_rect_region(held_weapon_texture(equipped),rect,source)
	draw_player_torch(p,size_scale,false)

func torch_grip()->Dictionary:
	# Identical left-hand pose/projection to the approved HD human rig.
	# Anatomical left is positive local X; do not flip with screen facing.
	var frame:int=avatar_frame()
	var cycle:float=float(frame)/8.0 if frame<8 else 0.0
	var bob:float=-0.014*cos(2.0*TAU*cycle) if frame<8 else 0.0
	var swing:float=-sin(TAU*cycle)*0.045 if frame<8 else 0.0
	if not action.is_empty() and equipped_weapon_index()>=0:
		bob=0.025*sin(PI*float(action_frame())/5.0);swing=0.0
	var local:=Vector3(0.438*1.25,0.72+bob,(0.15+swing)*1.5)
	var yaw:float=deg_to_rad(float(FACING_ANGLES[avatar_direction(facing)]))
	var rotated:=Vector3(local.x*cos(yaw)+local.z*sin(yaw),local.y,-local.x*sin(yaw)+local.z*cos(yaw))
	var tilt:float=deg_to_rad(23.0)
	var offset:=Vector2(rotated.x,-(rotated.y*cos(tilt)-rotated.z*sin(tilt)))*84.0*AVATAR_SCALE
	return {"offset":offset,"behind":rotated.z<0.0}

func draw_player_torch(p:Vector2,size_scale:float,behind:bool)->void:
	if not torch_lit or torch_fuel<=0:return
	var grip:Dictionary=torch_grip()
	if bool(grip.behind)!=behind:return
	draw_torch_paint(p+grip.offset*size_scale,size_scale,true,true)

func draw_torch_paint(grip:Vector2,s:float,lit:bool,palm:bool=false,opacity:float=1.0)->void:
	# Code-native flat pigment strokes, matching the small painted rig limbs.
	var bottom:=grip+Vector2(-1,8)*s
	var tip:=grip+Vector2(1,-16)*s
	draw_line(bottom,tip,Color(Color("5b4229"),opacity),4.0*s,true)
	draw_line(bottom+Vector2(-0.5,0)*s,tip,Color(Color("a97d46"),opacity),2.3*s,true)
	for i in range(4):
		var y:float=(-11.0-i*1.6)*s
		draw_line(grip+Vector2(-2.0*s,y),grip+Vector2(3.0*s,y-0.8*s),Color(Color("cfb77b"),opacity),1.6*s,true)
	if lit:
		var flicker:float=sin(elapsed*7.7)*0.65+sin(elapsed*13.1)*0.3
		var outer:=PackedVector2Array([tip+Vector2(-4,0)*s,tip+Vector2(-5,-5)*s,tip+Vector2(-2,-11)*s,tip+Vector2(flicker,-17)*s,tip+Vector2(3,-10)*s,tip+Vector2(5,-6)*s,tip+Vector2(4,0)*s])
		draw_colored_polygon(outer,Color(Color("c96835"),opacity))
		var inner:=PackedVector2Array([tip+Vector2(-2,0)*s,tip+Vector2(-3,-4)*s,tip+Vector2(flicker*0.4,-12)*s,tip+Vector2(3,-5)*s,tip+Vector2(2,0)*s])
		draw_colored_polygon(inner,Color(Color("f1bd5e"),opacity))
		draw_line(tip+Vector2(0,-1)*s,tip+Vector2(0.6,-7)*s,Color(Color("ffebad"),opacity),2.1*s,true)
	if palm:
		draw_circle(grip,2.7*s,Color(Color("e8a574"),opacity))
		draw_line(grip+Vector2(-1.5,0)*s,grip+Vector2(1.3,0.5)*s,Color(Color("f2b482"),opacity),1.6*s,true)

func person(p:Vector2,_color:Color,title:String,is_player:bool=false)->void:
	if is_player:draw_traveler(p)
	else:draw_npc(p,title)

func scenery_entry(kind: String, p: Vector2, index: int = -1) -> Dictionary:
	var depth: float = p.y
	var spec: Dictionary = model_spec(kind, p, index)
	if not spec.is_empty(): depth = model_depth(spec)
	return {"p": p, "kind": kind, "index": index, "depth": depth, "id": "%s:%s:%d" % [kind, str(p), index]}

func scenery_entries()->Array[Dictionary]:
	var entries:Array[Dictionary]=[]
	for p in trees:entries.append(scenery_entry("tree", p))
	for p in shrubs:entries.append(scenery_entry("shrub", p))
	for i in range(items.size()):
		if not items[i].get("dropped",false) or not items[i].taken: entries.append(scenery_entry("resource", items[i].pos, i))
	for i in range(props.size()):entries.append(scenery_entry("prop", props[i].p, i))
	for i in range(workbenches.size()):entries.append(scenery_entry("bench", workbenches[i].p, i))
	for i in range(ore_veins.size()):entries.append(scenery_entry("ore", ore_veins[i].p, i))
	entries.append(scenery_entry("cabin", Vector2(350,635)))
	for kind in beacon.kinds():entries.append(scenery_entry(kind, beacon.position(kind)))
	entries.append(scenery_entry("Rowan", npc_home));entries.append(scenery_entry("Ash", npc_position))
	entries.append(scenery_entry("player", player))
	if wildlife != null:
		for animal in wildlife.entries():
			entries.append({"p": animal.p, "kind": "animal", "index": -1, "depth": float(animal.p.y), "id": "animal:%d" % int(animal.uid), "animal": animal})
	entries.sort_custom(func(a,b): return a.depth < b.depth if absf(float(a.depth) - float(b.depth)) > 0.001 else str(a.id) < str(b.id))
	return entries

# Collision answers where boots may go. These cached painting bands answer
# which local part of scenery is in front of an actor at a legal position.
func prepare_pond_paint() -> void:
	pond_paint_layers.clear()
	for i in range(pools.size()):
		var display: Texture2D = paint_density.prepare_rect(pond_art[i], pools[i].size)
		pond_paint_layers.append(depth_layers.pond_layers(display, collision_profiles["pond_%d_rocks" % i], "pond:%d" % i))

func append_paint_bands(entries: Array[Dictionary], texture: Texture2D, rect: Rect2, profile: Dictionary, identity: String, foot: Vector2, mirror: bool, tint: Color, original_kind: String, index: int) -> void:
	var display_size := Vector2(texture.get_width(), texture.get_height())
	var band_index := 0
	var bands: Array[Dictionary] = depth_layers.bands(texture, profile, identity, rect.size)
	var front_actors: Array[Vector2] = []
	# A hand is wider than the boots. Once an actor stands beyond this local
	# facade edge, a neighboring stair column must not slice off the near arm.
	# This applies only to the actor's body span, never the entire obstacle.
	var actors: Array = [player, npc_home, npc_position]
	if wildlife != null:
		for animal in wildlife.entries(): actors.append(animal.p)
	for actor in actors:
		var local_x: float = (float(foot.x) - float(actor.x)) if mirror else (float(actor.x) - float(foot.x))
		var u: float = (local_x - rect.position.x) / rect.size.x
		if u < 0.0 or u >= 1.0: continue
		for band in bands:
			var source: Rect2 = band.source
			if u * display_size.x < source.position.x or u * display_size.x >= source.end.x: continue
			var front: float = foot.y + rect.position.y + float(band.depth_v) * rect.size.y
			if actor.y >= front + 2.0: front_actors.append(actor)
			break
	var fade_overhead: bool = not front_actors.has(player) and overhead_covers_player(texture, rect, foot, mirror, profile)
	var split_y: int = clampi(roundi(float(profile.get("overhead_split_v", 0.0)) * display_size.y), 0, int(display_size.y))
	for band in bands:
		var source: Rect2 = band.source
		var depth: float = foot.y + rect.position.y + float(band.depth_v) * rect.size.y
		var world_x0: float = foot.x + (-rect.position.x - source.end.x / display_size.x * rect.size.x if mirror else rect.position.x + source.position.x / display_size.x * rect.size.x)
		var world_x1: float = world_x0 + source.size.x / display_size.x * rect.size.x
		for actor in front_actors:
			if world_x1 >= actor.x - 40.0 and world_x0 <= actor.x + 40.0:
				depth = minf(depth, actor.y - 0.02)
		var portions: Array[Rect2] = [source]
		if fade_overhead and split_y > 0 and split_y < display_size.y:
			portions = [Rect2(source.position, Vector2(source.size.x, split_y)), Rect2(source.position.x, split_y, source.size.x, display_size.y - split_y)]
		for portion in portions:
			var local_rect := Rect2(rect.position + portion.position / display_size * rect.size, portion.size / display_size * rect.size)
			var color := tint
			if fade_overhead and portion.position.y < split_y: color.a *= 0.42
			entries.append({"kind": "paint_band", "original_kind": original_kind, "index": index, "p": foot, "texture": texture, "source": portion, "rect": local_rect, "mirror": mirror, "tint": color, "depth": depth, "id": identity + ":band:%04d" % band_index})
			band_index += 1

func overhead_covers_player(texture: Texture2D, rect: Rect2, foot: Vector2, mirror: bool, profile: Dictionary) -> bool:
	if player.y >= foot.y + rect.position.y + float(profile.get("depth_v", 1.0)) * rect.size.y: return false
	var split: float = float(profile.get("overhead_split_v", 0.0))
	if split <= 0.0: return false
	if not model_images.has(texture): model_images[texture] = texture.get_image()
	var image: Image = model_images[texture]
	for y in range(-74, -13, 12):
		for x in [-12, 0, 12]:
			var point: Vector2 = player + Vector2(x, y) - foot
			if mirror: point.x = -point.x
			var uv: Vector2 = (point - rect.position) / rect.size
			if uv.x >= 0.0 and uv.x < 1.0 and uv.y >= 0.0 and uv.y < split:
				if image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).a > 0.6: return true
	return false

func paint_entries(visible_only: bool = false) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var view := Rect2(camera, get_viewport_rect().size).grow(120)
	for entry in scenery_entries():
		var kind: String = str(entry.kind)
		var spec: Dictionary = model_spec(kind, entry.p, int(entry.index))
		if spec.is_empty() or (kind == "tree" and tree_live(entry.p)):
			entries.append(entry)
			continue
		var world_rect: Rect2 = sprite_rect(spec.texture, spec.foot, float(spec.height))
		if bool(spec.mirror): world_rect.position.x = spec.foot.x * 2.0 - world_rect.end.x
		if visible_only and not view.intersects(world_rect): continue
		var tint: Color = spec.get("tint", Color.WHITE)
		if kind == "resource": tint = Color(0.91, 0.94, 0.86)
		if kind == "ore" and ore_veins[int(entry.index)].depleted: tint = Color(0.84, 0.91, 0.88)
		var rect: Rect2 = sprite_rect(spec.texture, Vector2.ZERO, float(spec.height))
		var display: Texture2D = paint_density.prepare_rect(spec.texture, rect.size)
		append_paint_bands(entries, display, rect, collision_profiles[spec.profile], str(entry.id), spec.foot, bool(spec.mirror), tint, kind, int(entry.index))
	for i in range(pond_paint_layers.size()):
		var stone_index := 0
		for rock in pond_paint_layers[i].rocks:
			var rect := Rect2(pools[i].position + rock.rect.position * pools[i].size, rock.rect.size * pools[i].size)
			if not visible_only or view.intersects(rect):
				append_paint_bands(entries, rock.texture, rect, rock.profile, "bank_rock:%d:%d" % [i, stone_index], Vector2.ZERO, false, Color.WHITE, "bank_rock", i)
			stone_index += 1
	entries.sort_custom(func(a,b): return a.depth < b.depth if absf(float(a.depth) - float(b.depth)) > 0.001 else str(a.id) < str(b.id))
	return entries

func draw_paint_entry(entry: Dictionary) -> void:
	var p: Vector2 = entry.p
	match entry.kind:
		"paint_band":
			draw_set_transform(-camera + p, 0, Vector2(-1 if bool(entry.mirror) else 1, 1))
			draw_texture_rect_region(entry.texture, entry.rect, entry.source, entry.tint, false, false)
			draw_set_transform(-camera)
		"tree":
			var faded: bool = tree_covers_player(model_spec("tree", p))
			var shake := float(tree_states.get(p, {}).get("shake", 0.0))
			var sway: float = sin(elapsed * 58.0) * shake * 0.045
			varied_tree(p, faded, sway)
		"resource": draw_resource_node(int(entry.index))
		"Rowan", "Ash": person(p, Color.WHITE, str(entry.kind))
		"player": person(p, Color.WHITE, "", true)
		"animal": draw_animal(entry.animal)

func animal_pose(animal: Dictionary) -> Dictionary:
	var metadata: Dictionary = animal_metadata.get(str(animal.species), {})
	if metadata.is_empty(): return {}
	var angles: Array = metadata.get("angles", [0, 45, 90, 135, 180, 225, 270, 315])
	var heading: float = fposmod(rad_to_deg(atan2(animal.facing.x, animal.facing.y)), 360.0)
	var direction := 0
	var nearest := INF
	for index in range(angles.size()):
		var distance: float = absf(wrapf(heading - float(angles[index]), -180.0, 180.0))
		if distance < nearest: nearest = distance; direction = index
	var frames: int = int(metadata.get("frames", 4))
	var frame: int = mini(frames - 1, int(float(animal.frame) * frames / 8.0)) if bool(animal.moving) else 0
	if metadata.get("render_mode","") in ["painted-articulated-v1","painted-native-skin-v2"]:frame=0
	var cell := Vector2(float(metadata.cell[0]), float(metadata.cell[1]))
	var source := Rect2(Vector2(direction * cell.x, frame * cell.y), cell)
	var anchor := Vector2(float(metadata.anchor[0]), float(metadata.anchor[1]))
	var label_point := Vector2(anchor.x, anchor.y - float(metadata.get("reference_height_px", cell.y)))
	if metadata.has("poses"):
		var pose: Dictionary = metadata.poses[direction][frame]
		var raw: Array = pose.source_rect
		source = Rect2(float(raw[0]), float(raw[1]), float(raw[2]), float(raw[3]))
		anchor = Vector2(float(pose.anchor[0]), float(pose.anchor[1]))
		if pose.has("paint_bounds"):
			label_point = Vector2((float(pose.paint_bounds[0]) + float(pose.paint_bounds[2])) * 0.5, float(pose.paint_bounds[1]))
	var scale: float = float(metadata.world_height) / maxf(1.0, float(metadata.get("reference_height_px", cell.y)))
	return {"source": source, "anchor": anchor, "scale": scale, "direction": direction, "frame": frame, "label_offset": (label_point - anchor) * scale}

func draw_animal(animal: Dictionary) -> void:
	var species: String = str(animal.species)
	if not animal_atlases.has(species): return
	var pose: Dictionary = animal_pose(animal)
	if pose.is_empty(): return
	var source: Rect2 = pose.source
	var rect := Rect2(animal.p - pose.anchor * float(pose.scale), source.size * float(pose.scale))
	var tint := Color(0.27,0.19,0.40,0.88) if animal.get("shadow",false) else Color.WHITE
	tint.a *= float(animal.alpha)
	if float(animal.hitflash) > 0.0: tint = Color(1.0, 0.69, 0.52, tint.a)
	if animal_metadata[species].get("render_mode","") in ["painted-articulated-v1","painted-native-skin-v2"]:
		AnimalGait.draw(self,animal,animal_atlases[species],pose,animal_metadata[species],tint)
	else:draw_texture_rect_region(animal_atlases[species], rect, source, tint)

func draw_animal_status(animal: Dictionary) -> void:
	var species: String = str(animal.species)
	var pose: Dictionary = animal_pose(animal)
	if pose.is_empty(): return
	if species in ["wolf", "bear"] and ((lighting.sample(self,animal.p)>0.28 and animal.p.distance_to(player)<185.0) or bool(animal.warning)):
		# Combat warnings are screen overlays so a foreground hat or canopy cannot
		# hide the information needed to dodge. The animal itself still sorts by feet.
		var top: Vector2 = animal.p - camera + pose.label_offset + Vector2(0, -7)
		var health: float = clampf(float(animal.health) / maxf(1.0, float(animal.max_health)), 0, 1)
		draw_line(top + Vector2(-17, 0), top + Vector2(17, 0), Color("30473e"), 4, true)
		draw_line(top + Vector2(-17, 0), top + Vector2(-17 + 34 * health, 0), Color("c97c56"), 3, true)
		if bool(animal.warning):
			label_at(top + Vector2(-4, -9), "!", 22, Color("f1c47d"))
			if animal.state=="charge_warn":label_at(top+Vector2(-32,-32),"CHARGE",13,Color("f1c47d"))

func draw_animal_shadow(animal: Dictionary) -> void:
	var ground: Vector4 = wildlife.Data.ground(str(animal.species), animal.facing)
	var center: Vector2 = animal.p + Vector2(ground.x, ground.y)
	var points := PackedVector2Array()
	for index in range(20):
		var angle: float = TAU * index / 20.0
		var edge: float = 1.0 + sin(index * 2.3) * 0.045
		points.append(center + Vector2(cos(angle) * (ground.z * 0.94 + 2), sin(angle) * (ground.w * 0.7 + 1)) * edge)
	draw_colored_polygon(points, Color(0.06, 0.15, 0.12, 0.25 * float(animal.alpha)))

func draw_resource_node(index:int)->void:
	var item:Dictionary=items[index];var p:Vector2=item.pos
	if item.get("dropped",false):
		if item.taken:return
		if item.kind=="torch":
			draw_item_icon("torch",Rect2(p-Vector2(15,25),Vector2(30,35)))
			return
		var texture:Texture2D=item_icon(item.kind)
		if texture!=null:draw_texture_rect(paint_density.prepare_rect(texture,Vector2(30,26)),Rect2(p-Vector2(15,17),Vector2(30,26)),false)
		if int(item.get("qty",1))>1:label_at(p+Vector2(9,5),str(item.qty),12,Color("fff0b5"))
		return
	paint_model(model_spec("resource", p, index), Color(0.91,0.94,0.86))

func tree_covers_player(spec: Dictionary) -> bool:
	if player.y >= model_depth(spec): return false
	var rect: Rect2 = sprite_rect(spec.texture, spec.foot, float(spec.height))
	var image: Image = model_images[spec.texture]
	# Test real paint at the head/torso, rather than an arbitrary canopy rectangle.
	for y in range(-74, -13, 12):
		for x in [-12, 0, 12]:
			var sample: Vector2 = player + Vector2(x, y)
			if bool(spec.mirror): sample.x = float(spec.foot.x) * 2.0 - sample.x
			var uv: Vector2 = (sample - rect.position) / rect.size
			if uv.x >= 0 and uv.y >= 0 and uv.x < 1 and uv.y < 1:
				if image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).a > 0.6: return true
	return false

func draw_ellipse_shadow(p: Vector2) -> void:
	var progress := day_fraction()
	var cast := Vector2(lerpf(18, -18, progress), 4)
	var daylight := phase == "day" or phase == "dusk"
	# Irregular painted outline, attached to the feet independently of facing.
	var outline := PackedVector2Array()
	for i in range(28):
		var angle := TAU * i / 28.0
		var irregular := 1.0 + sin(i * 2.3) * 0.045
		outline.append(p + cast * 0.5 + Vector2(cos(angle) * (23 + absf(cast.x) * 0.5), sin(angle) * 8) * irregular)
	draw_colored_polygon(outline, Color(0.08, 0.17, 0.16, 0.30 if daylight else 0.17))
	ground_patch(3, p + cast * 0.4, Vector2(49, 20), 0.35)
	var contact := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		contact.append(p + Vector2(cos(angle) * 13, sin(angle) * 4.5))
	draw_colored_polygon(contact, Color(0.055, 0.12, 0.11, 0.26))

func draw_collision_overlay() -> void:
	for body in solid_bodies:
		if not body_active(body): continue
		var outline: PackedVector2Array = body.polygon.duplicate()
		outline.append(outline[0])
		var color: Color = Color("59ccff") if body.kind == "water" else (Color("d296c2") if body.kind == "resource" else Color("ff7852"))
		draw_polyline(outline, color, 1.25, true)
	for npc in [npc_home, npc_position]:
		var outline: PackedVector2Array = feet_polygon(npc)
		outline.append(outline[0]); draw_polyline(outline, Color("efb850"), 1.25, true)
	if wildlife != null:
		for animal in wildlife.animals:
			var contact: PackedVector2Array = wildlife.footprint(animal, animal.p)
			contact.append(contact[0])
			draw_polyline(contact, Color("8bc6b4"), 1.25, true)
	var outline: PackedVector2Array = feet_polygon(player)
	outline.append(outline[0]); draw_polyline(outline, Color("b4ffbd"), 1.25, true)
	draw_circle(player, 3, Color.WHITE)

func _draw() -> void:
	if font == null: return
	var screen := get_viewport_rect().size
	ground_layer.position = -camera
	draw_set_transform(-camera)
	for detail in ground_details: ground_patch(int(detail.variant), detail.p, detail.size, 0.36)
	for tree in trees:
		if tree_live(tree): ground_patch(0 if int(tree.x) % 2 else 1, tree + Vector2(0, 3), Vector2(94, 39), 0.58)
	ground_patch(2, Vector2(350, 634), Vector2(251, 65), 0.68)
	ground_patch(4, Vector2(354, 683), Vector2(113, 65), 0.46)
	for pool in pools:
		ground_patch(0, pool.get_center(), pool.size + Vector2(19, 17), 0.25)
	for i in range(pools.size()):
		if i < pond_paint_layers.size(): draw_texture_rect(pond_paint_layers[i].base, pools[i], false)
		var center: Vector2 = pools[i].get_center()
		for wave in range(3):
			var start := center + Vector2(-35 + wave * 27 + sin(elapsed + wave) * 3, -12 + wave * 14)
			draw_line(start, start + Vector2(17, -1), Color(0.78, 0.94, 0.87, 0.21), 1.5, true)
	label_at(Vector2(1580, 1360), "SOUTHERN WOODS", 19, Color("304c3c"))
	label_at(Vector2(1580, 195), "NORTHERN TRAIL", 19, Color("304c3c"))
	label_at(Vector2(940, 325), "STILLWATER LAKE", 18, Color("304c3c"))
	for item in items:
		if not item.get("dropped", false): ground_patch(1, item.pos + Vector2(0, 2), Vector2(51, 19), 0.22)
	# Contact shadows stay on the ground instead of darkening nearby bodies.
	for p in trees: draw_ellipse_shadow(p)
	for vein in ore_veins: draw_ellipse_shadow(vein.p)
	for p in [npc_home, npc_position, player]: draw_ellipse_shadow(p)
	if wildlife != null:
		for animal in wildlife.entries(): draw_animal_shadow(animal)
	beacon.draw_ground(self)
	for entry in paint_entries(true): draw_paint_entry(entry)
	label_at(Vector2(254, 665), "TRAVELERS CAMP", 18, Color("304c3c"))
	draw_action_effects()
	draw_stamina()
	var target := nearest_target()
	if not target.is_empty() and dialog.is_empty() and not inventory and not crafting and active_exploration():
		label_at(player + Vector2(-80, -98), target_prompt(target), 16, Color("fff0b5"))
	if show_collision: draw_collision_overlay()
	draw_set_transform(Vector2.ZERO)
	lighting.draw(self)
	draw_set_transform(-camera)
	beacon.draw_overlay(self)
	draw_set_transform(Vector2.ZERO)
	survival.draw(self,screen)
	draw_survival_ui(screen)
	if map_open and active_exploration(): map_view.draw(self, screen)
	if show_collision:
		paper_panel(Rect2(270, 155, 570, 31), Color("e9dcb6"), 6)
		label_at(Vector2(283, 177), "F3  green = feet / mint = wildlife / coral = solid / blue = water", 15)

func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
	# The hit area stays the full rect; only the painted button squashes.
	var held: bool = enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and rect.has_point(get_viewport().get_mouse_position())
	var shown: Rect2 = pressed_rect(rect, id, held)
	var size_scale: float = shown.size.y / rect.size.y
	paper_panel(shown, (Color("426d67").darkened(0.12) if held else Color("426d67")) if enabled else Color("304743"), 8)
	label_at(shown.position + Vector2(15 * size_scale, shown.size.y * 0.5 + (9 if mobile.enabled else 6) * size_scale), text, roundi((26 if mobile.enabled else 17) * size_scale), Color("f2edda") if enabled else Color("8e9d93"))
	if enabled: buttons.append({"rect": rect, "id": id})

func painted_status(origin: Vector2, title: String, value: float, icon: int, color: Color) -> void:
	if icon>=0:draw_texture_rect(status_art[icon],Rect2(origin + Vector2(0,5),Vector2(29,29)),false)
	else:draw_sanity_mark(origin+Vector2(14,20),12.0)
	label_at(origin + Vector2(39,17),title,15,Color("53634d"))
	label_at(origin + Vector2(222,17),"%d / 100" % (floori(clampf(value,0,100)) if icon<0 else ceili(clampf(value,0,100))),15,Color("53634d"))
	var bar := Rect2(origin + Vector2(39,23),Vector2(257,14))
	paper_panel(bar.grow(2),Color("8e9877"),4)
	var width := bar.size.x * clampf(value / 100.0,0,1)
	if width > 0:
		var outline := PackedVector2Array([bar.position,bar.position+Vector2(width,1),bar.position+Vector2(width,12),bar.position+Vector2(width*0.67,14),bar.position+Vector2(width*0.32,12),bar.position+Vector2(0,14)])
		draw_colored_polygon(outline,color)
		for i in range(7):
			var x := (i + 0.5) * width / 7.0
			draw_line(bar.position+Vector2(x-4,4+i%2),bar.position+Vector2(minf(width,x+6),5+i%2),Color(1,0.94,0.73,0.10),2,true)

func draw_survival_ui(screen: Vector2) -> void:
	buttons.clear()
	if mobile.enabled:
		mobile_ui.draw(self,screen);return
	if wildlife != null and active_exploration():
		for animal in wildlife.entries(): draw_animal_status(animal)
	paper_panel(Rect2(12,8,screen.x-24,135),Color("e9dcb6"))
	label_at(Vector2(24,32),"FOREST WANDERER",25)
	label_at(Vector2(335,31),"v0.1.7-alpha.1  /  THE OLD BEACON",15,Color("657259"))
	var timer_title:="NIGHT IN "+clock_text()
	if phase=="dusk":timer_title="DUSK "+clock_text()
	elif phase=="night":timer_title="DAWN IN "+clock_text()
	elif phase=="result" or won:timer_title="DAWN"
	elif lost:timer_title="NIGHT "+str(night)
	label_at(Vector2(screen.x-265,32),timer_title,22,Color("875c31"))
	painted_status(Vector2(24,43),"Health",health,0,Color("b7674c"))
	painted_status(Vector2(354,43),"Fullness",float(fullness),1,Color("bc984e"))
	painted_status(Vector2(24,88),"Sanity  "+survival.level(sanity),sanity,-1,Color("827b9e"))
	label_at(Vector2(354,116),"Resting in camp" if survival.resting else ("Hungry: slower movement" if fullness<25 else "Light protects your sanity"),15,Color("657259"))
	label_at(Vector2(696,66),"Day %d   |   Beacon parts %d / 3" % [night,beacon.parts_found()],16)
	label_at(Vector2(696,92),"H heal   |   B bag   |   C craft   |   T torch",14)
	label_at(Vector2(696,118),"Bag %d / %d   |   Logs %d   Ore %d" % [bag.used_slots(),bag.slots.size(),bag.count("log"),bag.count("ore")],15)
	var modal:=inventory or crafting or paused or not dialog.is_empty() or not active_exploration()
	if active_exploration() and not modal:
		var sky_state:Dictionary=lighting.atmosphere(self)
		var time_name:String=str(sky_state.title)
		var timer_label:String=("Dawn in " if phase=="night" else "Night in ")+clock_text()
		var sky:Color=sky_state.sky
		var sky_progress:float=float(sky_state.fraction)
		var clock_color:Color=Color("e9dcb6") if float(sky_state.darkness)>0.35 else Color("35483d")
		label_at(Vector2(24,172),time_name,16,clock_color)
		label_at(Vector2(24,199),timer_label,21,clock_color)
		draw_rect(Rect2(24,216,225,32),sky)
		draw_circle(Vector2(37+sky_progress*198,240-sin(sky_progress*PI)*15),7,Color("e9ecdf") if phase=="night" else Color("fff0b4"))
		if phase=="night":
			var in_refuge:bool=player.distance_to(CAMP)<160.0
			var hint:String=("CAMP REST - sanity recovers" if survival.resting else "CAMP LIGHT - slows threats; stay alert") if in_refuge else ("TORCH %d s  |  T put out  |  Space / click strike"%ceili(torch_fuel) if torch_lit else "T light torch  |  C craft: 2 branches + 2 fibers")
			paper_panel(Rect2(20,262,385 if in_refuge else 495,33),Color("e6d8b3"),8)
			label_at(Vector2(30,285),hint,15)
		var goal:String="GOAL  "+beacon.objective(self)
		var goal_y:float=304.0 if phase=="night" else 262.0
		paper_panel(Rect2(20,goal_y,font.get_string_size(goal,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+24,33),Color("efe0b0"),8)
		label_at(Vector2(32,goal_y+23),goal,15,Color("6a4a22"))
	label_at(Vector2(24,screen.y-88),"WASD move   Shift sprint   E gather   Space / click use   1-6 select   B bag   C craft   H heal   T torch   M map",14,Color("e9dcb6"))
	draw_hotbar(screen)
	if message_time>0 and not modal:
		paper_panel(Rect2(20,screen.y-158,screen.x-40,35),Color("e6d8b3"),8)
		label_at(Vector2(34,screen.y-134),message,15)
	if not modal:return
	draw_rect(Rect2(Vector2.ZERO,screen),Color(0.02,0.06,0.07,0.50))
	var base:=screen*0.5-Vector2(475,275)
	paper_panel(Rect2(base,Vector2(950,550)),Color("e9dcb6"),16)
	if paused:
		label_at(base+Vector2(35,70),"PAUSED",32)
		label_at(base+Vector2(35,125),"Time, animals and actions are paused.",20)
		label_at(base+Vector2(35,175),"The backpack, crafting and conversations also pause the world.",18)
		label_at(base+Vector2(35,215),"Closing the game resets this run.",18)
		ui_button(Rect2(base+Vector2(35,465),Vector2(220,48)),"Esc  Resume","resume")
	elif inventory:draw_backpack_panel(base)
	elif crafting:draw_crafting_panel(base)
	elif not dialog.is_empty():
		var lines:=dialog.split("\n")
		for i in range(lines.size()):label_at(base+Vector2(30,45+i*34),lines[i],21 if i==0 else 17)
		ui_button(Rect2(base+Vector2(30,492),Vector2(250,42)),"E / Space  Continue","close")
	else:
		var title:="NIGHT %d SURVIVED" % night
		if won:title="BEACON LIT - YOU ESCAPED THE FOREST!"
		if lost:title="GAME OVER - NIGHT "+str(night)
		label_at(base+Vector2(35,70),title,27)
		label_at(base+Vector2(35,140),result_text,18)
		label_at(base+Vector2(35,200),"Health %d/100   |   Fullness %d/100" % [int(health),fullness],20)
		label_at(base+Vector2(35,250),"Medicine left: %d   |   Nights survived: %d   |   Beacon parts %d / 3" % [bag.count("medicine"),survived,beacon.parts_found()],19)
		label_at(base+Vector2(35,300),food_check(),19)
		if won:label_at(base+Vector2(35,365),"Its light shows the way home. You leave the forest at last.",21)
		elif lost:label_at(base+Vector2(35,365),"Keep your distance, carry food and repair your tools.",18)
		else:label_at(base+Vector2(35,365),"Morning arrives. Felled trees and placed benches remain.",18)
		if won or lost:ui_button(Rect2(base+Vector2(35,440),Vector2(240,48)),"R  New run","restart")
		else:ui_button(Rect2(base+Vector2(35,440),Vector2(340,48)),"Enter  Prepare for night "+str(night+1),"morning")

func selected_item()->Dictionary:
	return bag.item_by_uid(hotbar[active_hotbar])
func sanitize_hotbar()->void:
	for i in range(6):
		if bag.index_of_uid(hotbar[i])<0:hotbar[i]=-1
func bind_hotbar(uid:int,slot:int)->bool:
	var item:Dictionary=bag.item_by_uid(uid)
	if item.is_empty() or slot<0 or slot>=6:return false
	if Data.info(item.id).category in ["material","quest"]:
		notify("Materials and beacon parts stay in the backpack. Equip a tool, food or workbench.");return false
	for i in range(6):
		if hotbar[i]==uid:hotbar[i]=-1
	hotbar[slot]=uid;active_hotbar=slot;cancel_action()
	return true
func auto_equip(uid:int)->void:
	for i in range(6):
		if hotbar[i]<0:bind_hotbar(uid,i);return
	bind_hotbar(uid,active_hotbar)
func give_item(id:String,quantity:int,at:Vector2=Vector2.ZERO)->int:
	var added:int=bag.add(id,quantity)
	if added<quantity:
		var point:Vector2=player+Vector2(19,12) if at==Vector2.ZERO else at
		items.append({"pos":point,"kind":id,"taken":false,"variant":0,"dropped":true,"qty":quantity-added})
	sanitize_hotbar()
	return added
func tree_live(p:Vector2)->bool:
	return not bool(tree_states.get(p,{}).get("felled",false))

func body_active(body: Dictionary) -> bool:
	if body.kind != "resource": return true
	var index: int = int(body.index)
	return index < items.size() and not items[index].taken and not items[index].get("dropped", false)

func append_model_body(kind: String, p: Vector2, index: int = -1) -> void:
	var spec: Dictionary = model_spec(kind, p, index)
	if spec.is_empty(): return
	var identity: String = "%s:%s:%d" % [kind, str(p), index]
	var depth: float = model_depth(spec)
	var contours: Array[PackedVector2Array] = model_polygons(spec)
	body_lookup[identity] = {"profile": spec.profile, "polygons": contours, "depth": depth}
	for polygon in contours:
		var bounds: Rect2 = Geometry.polygon_bounds(polygon)
		solid_bodies.append({"id": identity, "kind": kind, "p": p, "index": index, "profile": spec.profile, "polygon": polygon, "bounds": bounds, "depth": depth})
		obstacles.append(bounds) # Broad-phase cache only; never the collision shape.

func rebuild_obstacles()->void:
	obstacles.clear(); solid_bodies.clear(); body_lookup.clear(); pond_colliders.clear()
	append_model_body("cabin", Vector2(350, 635))
	for kind in beacon.kinds(): append_model_body(kind, beacon.position(kind))
	for i in range(props.size()): append_model_body("prop", props[i].p, i)
	for p in trees: append_model_body("tree", p)
	for p in shrubs: append_model_body("shrub", p)
	for i in range(workbenches.size()): append_model_body("bench", workbenches[i].p, i)
	for i in range(ore_veins.size()): append_model_body("ore", ore_veins[i].p, i)
	for i in range(items.size()):
		if not items[i].get("dropped", false) and not items[i].taken and items[i].kind not in ["rope", "branch", "berry"]:
			append_model_body("resource", items[i].pos, i)
	for i in range(pools.size()):
		var profile_key: String = "pond_%d" % i
		for raw in collision_profiles[profile_key].polygons:
			var polygon := PackedVector2Array()
			for pair in raw: polygon.append(pools[i].position + Vector2(float(pair[0]), float(pair[1])) * pools[i].size)
			pond_colliders.append(polygon)
			solid_bodies.append({"id": "water:%d" % i, "kind": "water", "p": pools[i].get_center(), "index": i, "profile": profile_key, "polygon": polygon, "bounds": Geometry.polygon_bounds(polygon), "depth": 0.0})
		# Bank rocks have independent ground bases, separate from fishable water
		# and from the full visual masks used to extract their native paint.
		var rocks_key: String = "pond_%d_rocks" % i
		var stone_index := 0
		for raw in collision_profiles[rocks_key].polygons:
			var polygon := PackedVector2Array()
			var center := Vector2.ZERO
			for pair in raw:
				var point: Vector2 = pools[i].position + Vector2(float(pair[0]), float(pair[1])) * pools[i].size
				polygon.append(point); center += point
			center /= polygon.size()
			solid_bodies.append({"id": "bank_rock:%d:%d" % [i,stone_index], "kind": "bank_rock", "p": center, "index": i, "profile": rocks_key, "polygon": polygon, "bounds": Geometry.polygon_bounds(polygon), "depth": Geometry.polygon_bounds(polygon).end.y})
			stone_index += 1
func setup_features_world()->void:
	tree_states.clear();ore_veins.clear()
	for p in trees:tree_states[p]={"hp":3,"felled":false,"shake":0.0}
	workbenches=[{"uid":1,"p":Vector2(620,704)}];next_bench_uid=2
	rebuild_obstacles()
	var rng=RandomNumberGenerator.new();rng.seed=154
	for center in [Vector2(805,630),Vector2(1430,615),Vector2(660,1080),Vector2(1880,1110)]:
		for attempt in range(80):
			var p:Vector2=center+Vector2(rng.randf_range(-115,115),rng.randf_range(-100,100))
			if not static_walkable(p) or not static_walkable(p+Vector2(0,38)):continue
			var close:bool=quest_site_near(p,120.0)
			for vein in ore_veins:
				if p.distance_to(vein.p)<130:close=true
			if close:continue
			ore_veins.append({"p":p,"hp":3,"depleted":false,"variant":ore_veins.size()%3})
			break
	rebuild_obstacles()
	setup_npcs();npc_roaming.setup(self,resource_seed);rebuild_navigation()
func static_walkable(p:Vector2)->bool:
	if p.x<32 or p.y<40 or p.x>WORLD.x-32 or p.y>WORLD.y-32:return false
	var polygon: PackedVector2Array = feet_polygon(p)
	var bounds: Rect2 = Geometry.polygon_bounds(polygon)
	for body in solid_bodies:
		if body_active(body) and Geometry.bounds_overlap(bounds, body.bounds) and Geometry.polygons_overlap(polygon, body.polygon): return false
	return true
func setup_npcs()->void:
	npc_home=CAMP;npc_position=npc_scout
	npc_states={
	"Rowan":{"p":npc_home,"facing":Vector2.DOWN,"moving":false,"walk":0.0,"speed":30.0,
		"route":[CAMP,Vector2(570,802),Vector2(686,765),Vector2(510,824)],"waypoint":1,"path":PackedVector2Array(),"cursor":0,"replan":0.0,"wait":1.0},
	"Ash":{"p":npc_position,"facing":Vector2.LEFT,"moving":false,"walk":0.0,"speed":43.0,
		"route":[npc_scout,Vector2(1180,970),Vector2(1330,1080),Vector2(1460,970),Vector2(1340,870)],
		"waypoint":1,"path":PackedVector2Array(),"cursor":0,"replan":0.0,"wait":0.3}}
func rebuild_navigation()->void:
	nav_grid=AStarGrid2D.new()
	nav_grid.region=Rect2i(0,0,ceili(WORLD.x / NAV_CELL),ceili(WORLD.y / NAV_CELL));nav_grid.cell_size=Vector2(NAV_CELL,NAV_CELL);nav_grid.offset=Vector2(NAV_CELL,NAV_CELL)*0.5
	nav_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav_grid.update()
	for y in range(nav_grid.region.size.y):
		for x in range(nav_grid.region.size.x):
			var id:Vector2i=Vector2i(x,y)
			nav_grid.set_point_solid(id,not static_walkable(nav_grid.get_point_position(id)))
	nav_revision+=1
	for name in npc_states:npc_states[name].replan=0.0
func nav_cell(p:Vector2)->Vector2i:
	var base:Vector2i=Vector2i(int(p.x/NAV_CELL),int(p.y/NAV_CELL))
	var nearest:Vector2i=Vector2i(-1,-1)
	var distance:float=INF
	for dy in range(-3,4):
		for dx in range(-3,4):
			var id:Vector2i=base+Vector2i(dx,dy)
			if not nav_grid.region.has_point(id) or nav_grid.is_point_solid(id):continue
			var d:float=p.distance_squared_to(nav_grid.get_point_position(id))
			if d<distance:distance=d;nearest=id
	return nearest
func npc_walkable(p:Vector2,name:String)->bool:
	if not static_walkable(p) or Geometry.polygons_overlap(feet_polygon(p),feet_polygon(player)):return false
	if wildlife != null and wildlife.body_blocked(p): return false
	for other in npc_states:
		if other!=name and Geometry.polygons_overlap(feet_polygon(p),feet_polygon(npc_states[other].p)):return false
	return true
func update_npcs(dt:float)->void:
	npc_roaming.update(self,dt)
func nearby_bench()->int:
	var best:float=92.0;var uid:int=-1
	for bench in workbenches:
		var distance:float=player.distance_to(bench.p)
		if distance<best and target_line_clear(bench.p):best=distance;uid=int(bench.uid)
	return uid
func bench_available()->bool:
	if crafting_station<0:return false
	for bench in workbenches:
		if int(bench.uid)==crafting_station:return player.distance_to(bench.p)<96 and target_line_clear(bench.p)
	return false
func visible_recipes()->Array[int]:
	var result:Array[int]=[]
	for i in range(Data.RECIPES.size()):
		if not Data.RECIPES[i].bench or bench_available():result.append(i)
	return result
func repair_held() -> void:
	if nearby_bench() < 0:
		notify("Repairs need a nearby workbench.")
		return
	var item: Dictionary = bag.slots[selected_slot] if inventory and selected_slot >= 0 else selected_item()
	if item.is_empty() or not item.has("durability"):
		notify("Choose a tool with durability to repair.")
		return
	if bag.repair(int(item.uid), Data.REPAIR_COST):
		notify("Repaired " + Data.label(item.id) + ".")
	else:
		notify("Repair needs 2 branches, 1 rock and 1 fiber, or the tool is already sound.")

func place_point()->Vector2:return player+facing.normalized()*80
func can_place_bench(p:Vector2)->bool:
	if p.x<70 or p.y<100 or p.x>WORLD.x-70 or p.y>WORLD.y-50:return false
	for contour in model_polygons(model_spec("bench", p)):
		var expanded: Array[PackedVector2Array] = Geometry2D.offset_polygon(contour, 4.0)
		if expanded.is_empty(): expanded.append(contour)
		for polygon in expanded:
			var bounds: Rect2 = Geometry.polygon_bounds(polygon)
			if wildlife != null and wildlife.body_blocked(p, -1, polygon): return false
			for body in solid_bodies:
				if body_active(body) and Geometry.bounds_overlap(bounds, body.bounds) and Geometry.polygons_overlap(polygon, body.polygon): return false
			for npc in [player,npc_home,npc_position]:
				if Geometry.polygons_overlap(polygon, feet_polygon(npc)): return false
	return true
func place_workbench()->bool:
	var item:Dictionary=selected_item();var p:Vector2=place_point()
	if item.get("id","")!="workbench" or not can_place_bench(p):notify("Choose clear ground in front of you for the workbench.");return false
	bag.remove_uid(int(item.uid),1);sanitize_hotbar()
	workbenches.append({"p":p,"uid":next_bench_uid});next_bench_uid+=1
	rebuild_obstacles();rebuild_navigation()
	notify("Workbench placed. Move close and press E to craft.")
	return true
func nearest_water()->Dictionary:
	var result:Dictionary={};var best:float=90.0
	for i in range(pond_colliders.size()):
		var polygon:PackedVector2Array=pond_colliders[i]
		for k in range(polygon.size()):
			var edge:Vector2=Geometry2D.get_closest_point_to_segment(player,polygon[k],polygon[(k+1)%polygon.size()])
			var distance:float=player.distance_to(edge)
			if distance<best and target_line_clear(edge):
				best=distance;result={"kind":"water","index":i,"pos":edge,"cast":edge+(edge-player).normalized()*29}
	return result
func target_is_valid(target:Dictionary)->bool:
	if not active_exploration() or paused or inventory or crafting or not dialog.is_empty() or target.is_empty() or player.distance_to(target.pos)>92:return false
	# A swing can miss harmlessly next to scenery; each animal hit has its own
	# line-of-sight check so a short aim marker cannot cancel a reachable hit.
	if target.kind == "swing": return true
	if not target_line_clear(target.pos): return false
	match target.kind:
		"tree":return tree_states.has(target.pos) and tree_live(target.pos)
		"ore":return int(target.index)<ore_veins.size() and not ore_veins[int(target.index)].depleted
		"rune_rock":return beacon.rune_valid()
		"water":return not nearest_water().is_empty()
		"swing":return true
	return false
func cancel_action()->void:action.clear()
func begin_action(target:Dictionary)->bool:
	if not action.is_empty() or not active_exploration() or paused or inventory or crafting or not dialog.is_empty() or interaction_cooldown>0:return false
	var item:Dictionary=selected_item()
	if item.is_empty() or not bag.usable(int(item.uid)):notify("Equip a usable tool in slots 1-6. Repair broken tools at a workbench.");return false
	var type:String=str(Data.info(item.id).get("tool",""))
	var required:String={"tree":"axe","ore":"pick","rune_rock":"pick","water":"rod"}.get(target.get("kind",""),"")
	if not required.is_empty() and type!=required:
		notify({"axe":"Equip an axe to chop this tree.","pick":"Equip a pickaxe to mine iron ore or break the rune rock.","rod":"Equip a fishing rod beside water."}[required]);return false
	if not target_is_valid(target):return false
	facing=(target.pos-player).normalized() if target.kind!="swing" else facing
	action={"target":target.duplicate(true),"uid":int(item.uid),"id":item.id,"elapsed":0.0,"duration":Balance.action_duration(str(item.id),str(target.kind),fullness),"hit":false}
	return true
func action_frame()->int:
	if action.is_empty():return 0
	var t:float=float(action.elapsed)/float(action.duration)
	if action.target.kind=="water":
		if t<0.3:return mini(3,int(t/0.3*4))
		if t<0.88:return 3
		return mini(5,4+int((t-0.88)/0.12*2))
	return mini(5,int(t*6))
func commit_action()->void:
	if action.is_empty() or action.hit:return
	var target:Dictionary=action.target;var uid:int=int(action.uid)
	if not target_is_valid(target) or not bag.usable(uid):cancel_action();return
	action.hit=true
	if target.kind=="swing":
		var weapon: Dictionary = Data.info(action.id)
		if wildlife != null and str(weapon.get("tool", "")) != "rod":
			var damage: float = float(weapon.get("damage", 12 + int(weapon.get("power", 1)) * 6))
			var result: Dictionary = wildlife.attack(self, player, facing, damage, float(weapon.get("reach", 68)), 0.20)
			if int(result.hits) > 0:
				bag.damage(uid, 1)
				if not result.kills.is_empty():
					notify("Threat defeated. Keep your equipment repaired.")
				if not bag.usable(uid): notify(Data.label(action.id) + " broke. Repair it at a workbench.")
		return
	bag.damage(uid,1)
	var spec:Dictionary=Data.info(action.id)
	match target.kind:
		"tree":
			var state:Dictionary=tree_states[target.pos]
			state.hp-=int(spec.get("strength",1));state.shake=0.3
			harvest_effects.append({"p":target.pos,"age":0.0,"kind":"wood"})
			if state.hp<=0:
				state.felled=true
				give_item("log",4,target.pos+Vector2(-12,9));give_item("branch",2,target.pos+Vector2(14,13))
				rebuild_obstacles();rebuild_navigation();notify("Tree felled: 4 logs + 2 branches. Extra loot stays on the ground.")
		"ore":
			var vein:Dictionary=ore_veins[int(target.index)]
			vein.hp-=int(spec.get("strength",1))
			harvest_effects.append({"p":target.pos,"age":0.0,"kind":"stone"})
			if vein.hp<=0:
				vein.depleted=true
				give_item("ore",3,target.pos+Vector2(-10,9));give_item("rock",2,target.pos+Vector2(15,12))
				rebuild_obstacles();rebuild_navigation();notify("Mined: 3 iron ore + 2 rocks.")
		"rune_rock":beacon.mine_hit(self,int(spec.get("strength",1)))
		"water":
			if beacon.fish_catch(self,target.pos):
				if not bag.usable(uid):notify(Data.label(action.id)+" broke. Repair it at a workbench.")
				return
			var before:int=bag.count("fish")
			give_item("fish",1,player+Vector2(18,11))
			if before==0 and bag.count("fish")>0:
				var i:int=bag.first("fish")
				for slot in range(6):
					if hotbar[slot]<0:hotbar[slot]=int(bag.slots[i].uid);break
			notify("Caught a fish! Equip it and use to restore 25 fullness.")
	if not bag.usable(uid):notify(Data.label(action.id)+" broke. Repair it at a workbench.")
func update_action(dt:float)->void:
	interaction_cooldown=maxf(0,interaction_cooldown-dt)
	for p in tree_states:tree_states[p].shake=maxf(0,float(tree_states[p].shake)-dt)
	for effect in harvest_effects:effect.age+=dt
	harvest_effects=harvest_effects.filter(func(e):return e.age<0.65)
	if action.is_empty():return
	if not active_exploration() or inventory or crafting or not dialog.is_empty():cancel_action();return
	if selected_item().get("uid",-1)!=action.uid or not target_is_valid(action.target):
		if not action.hit:cancel_action();return
	action.elapsed+=dt
	var trigger:float=0.99 if action.target.kind=="water" else 0.62
	if not action.hit and float(action.elapsed)>=float(action.duration)*trigger:commit_action()
	if not action.is_empty() and float(action.elapsed)>=float(action.duration):
		action.clear();interaction_cooldown=0.12
func use_selected()->void:
	if not active_exploration() or paused or inventory or crafting or not dialog.is_empty():return
	var item:Dictionary=selected_item()
	if item.is_empty():interact();return
	if item.id=="workbench":place_workbench();return
	if item.id=="fish":
		if fullness>=100:notify("You are already well fed.");return
		var restored:int=mini(25,100-fullness)
		bag.remove_uid(int(item.uid));fullness+=restored;survival.eat(self,4.0*restored/25.0);sanitize_hotbar()
		notify("Ate fish. Fullness +%d, sanity +%.1f."%[restored,4.0*restored/25.0]);return
	if item.id=="medicine":use_medicine();return
	if item.id=="torch":toggle_torch(int(item.uid));return
	if item.id=="crystal":notify("Keep it in your bag: one magic stone blocks one animal attack.");return
	var tool: String = str(Data.info(item.id).get("tool", ""))
	var target: Dictionary = {}
	if tool == "weapon":
		target = {"kind":"swing", "pos":player + facing * 35}
	elif tool == "rod": target = nearest_water()
	elif wildlife != null and not wildlife.target_near(player, facing, 68.0).is_empty():
		target = {"kind":"swing", "pos":player + facing * 35}
	else:
		target = nearest_target(true)
		if not target.is_empty() and ((tool == "axe" and target.kind != "tree") or (tool == "pick" and target.kind not in ["ore", "rune_rock"])): target = {}
	if target.is_empty():target={"kind":"swing","pos":player+facing*35}
	begin_action(target)
func item_icon(id:String)->Texture2D:
	var spec:Dictionary=Data.info(id)
	if spec.is_empty():return null
	var index:int=int(spec.icon)
	match spec.family:
		"utility":return utility_icons[index] if index<utility_icons.size() else null
		"equipment":return equipment_art[index] if index<equipment_art.size() else null
		"resource":return resource_art[index] if index<resource_art.size() else null
		"beacon":return beacon.icons[index] if index<beacon.icons.size() else null
	return null
func draw_item_icon(id:String,rect:Rect2,opacity:float=1.0)->void:
	if id=="torch":
		draw_torch_paint(rect.position+Vector2(rect.size.x*0.5,rect.size.y*0.77),rect.size.y/44.0,true,false,opacity)
		return
	var texture:Texture2D=item_icon(id)
	if texture!=null:draw_texture_rect(texture,rect,false,Color(1,1,1,opacity))
func npc_direction(direction:Vector2)->int:
	var angle:float=fposmod(rad_to_deg(atan2(direction.x,direction.y)),360)
	return int(round(angle/45.0))%8
func draw_npc(p:Vector2,name:String)->void:
	if not npc_states.has(name) or not npc_atlases.has(name):return
	var npc:Dictionary=npc_states[name]
	var frame:int=int(float(npc.walk)/WALK_STRIDE*8)%8 if npc.moving else 8
	var direction:int=npc_direction(npc.facing)
	var source:Rect2=Rect2(Vector2(direction*AVATAR_CELL.x,frame*AVATAR_CELL.y),AVATAR_CELL)
	var rect:Rect2=Rect2(p-AVATAR_ANCHOR*AVATAR_SCALE,AVATAR_CELL*AVATAR_SCALE)
	draw_texture_rect_region(npc_atlases[name],rect,source)
	if name=="Rowan" and rowan_lantern!=null:draw_texture_rect_region(rowan_lantern,rect,source)
	label_at(p+Vector2(-24,-83),name,16,Color("304c3c"))
func draw_action_effects()->void:
	for effect in harvest_effects:
		for i in range(6):
			var t:float=float(effect.age)
			var p:Vector2=effect.p+Vector2((i-2.5)*t*39,-sin(t*PI/0.65)*20+t*17)
			var color:Color=Color("b58243") if effect.kind=="wood" else Color("829699")
			draw_colored_polygon(PackedVector2Array([p+Vector2(-2,-1),p+Vector2(2,-2),p+Vector2(3,1),p+Vector2(-1,2)]),Color(color,1-t/0.65))
	if not action.is_empty() and action.target.kind=="water":
		var direction:int=avatar_direction(facing);var frame:int=action_frame()
		var meta:Dictionary=use_metadata.get("%d_%d"%[direction,frame],{})
		var point:Vector2=player+Vector2(8,-48)
		if meta.has("rod_tip"):point=player+(Vector2(meta.rod_tip[0],meta.rod_tip[1])-USE_ANCHOR)*AVATAR_SCALE
		var cast:Vector2=action.target.cast+Vector2(0,sin(elapsed*3)*1.2)
		draw_line(point,cast,Color("d4caa0"),1.2,true)
		draw_circle(cast,3.0,Color("c16d49"));draw_circle(cast+Vector2(0,-1.5),1.5,Color("e9d7a7"))
	if not action.is_empty():
		var t:float=clampf(float(action.elapsed)/float(action.duration),0,1)
		var rect:Rect2=Rect2(player+Vector2(-32,-106),Vector2(64,6))
		draw_rect(rect,Color(0.2,0.3,0.22,0.8))
		draw_rect(Rect2(rect.position,Vector2(64*t,6)),Color("dec17a"))
func target_prompt(target:Dictionary)->String:
	match target.kind:
		"guide","scout":return "E  Talk"
		"bench":return "E  Workbench"
		"tree":return "E / Hold  Chop tree (axe)" if not action.is_empty() else "Hold E  Chop tree - axe required"
		"ore":return "Hold E  Mine ore - pickaxe required"
		"beacon","rune_rock","shrine":return beacon.prompt(str(target.kind))
		"water":return "Hold E  Fish"
		"item":return "E  "+("Eat berries" if items[int(target.index)].kind=="berry" else "Take "+item_name(items[int(target.index)].kind))
	return ""

func update_navigation_area(point: Vector2) -> void:
	if nav_grid == null: return
	# A harvested node only affects nearby navigation cells. Avoid rebuilding
	# the entire detailed forest on every pickup.
	var minimum := Vector2i(floori((point.x - 80) / NAV_CELL), floori((point.y - 80) / NAV_CELL))
	var maximum := Vector2i(ceili((point.x + 80) / NAV_CELL), ceili((point.y + 80) / NAV_CELL))
	for y in range(maxi(0, minimum.y), mini(nav_grid.region.end.y, maximum.y + 1)):
		for x in range(maxi(0, minimum.x), mini(nav_grid.region.end.x, maximum.x + 1)):
			var id := Vector2i(x, y)
			nav_grid.set_point_solid(id, not static_walkable(nav_grid.get_point_position(id)))
	nav_revision += 1
	for name in npc_states: npc_states[name].replan = 0.0

func total_power() -> int:
	return bag.best_power()

func bag_slot_rect(index: int) -> Rect2:
	if mobile.enabled: return mobile_ui.bag_slot_rect(self,index)
	var base := get_viewport_rect().size * 0.5 - Vector2(475, 275)
	return Rect2(base + Vector2(25 + (index % 8) * 72, 88 + floori(float(index) / 8.0) * 72), Vector2(64, 64))

func bag_hotbar_rect(index: int) -> Rect2:
	if mobile.enabled: return mobile_ui.bag_hotbar_rect(self,index)
	var base := get_viewport_rect().size * 0.5 - Vector2(475, 275)
	return Rect2(base + Vector2(25 + index * 72, 370), Vector2(64, 64))

func bag_slot_at(point: Vector2) -> int:
	for i in range(bag.slots.size()):
		if bag_slot_rect(i).has_point(point): return i
	return -1

func bag_hotbar_at(point: Vector2) -> int:
	for i in range(6):
		if bag_hotbar_rect(i).has_point(point): return i
	return -1

func draw_item_slot(rect: Rect2, item: Dictionary, selected: bool, number: int = -1) -> void:
	paper_panel(rect, Color("d9c79d") if selected else Color("efe4c4"), 8)
	if selected: draw_rect(rect.grow(-1), Color("ad8748"), false, 3)
	var scale:float=rect.size.x/64.0
	if number>=0:label_at(rect.position+Vector2(4,15)*scale,str(number+1),int(13*scale),Color("657259"))
	if item.is_empty():return
	draw_item_icon(str(item.id),Rect2(rect.position+Vector2(10,9)*scale,Vector2(44,42)*scale))
	if int(item.get("qty",1))>1:label_at(rect.position+Vector2(43,54)*scale,str(item.qty),int(14*scale))
	if item.has("fuel"):label_at(rect.position+Vector2(6,59)*scale,"%ds"%ceili(float(item.fuel)),int(12*scale),Color("875c31"))
	if item.has("durability"):
		var maximum:=maxi(1,int(Data.info(item.id).get("durability",1)))
		draw_rect(Rect2(rect.position+Vector2(8,59)*scale,Vector2(48,3)*scale),Color("7a7058"))
		var width:=48.0*float(item.durability)/maximum
		if width>0:draw_rect(Rect2(rect.position+Vector2(8,59)*scale,Vector2(width,3)*scale),Color("617e56"))

func draw_hotbar(screen: Vector2) -> void:
	var slot_size := Vector2(58, 58)
	var gap := 8.0
	var total := slot_size.x * 6 + gap * 5
	var origin := Vector2((screen.x - total) * 0.5, screen.y - 69)
	paper_panel(Rect2(origin - Vector2(9, 7), Vector2(total + 18, 66)), Color("e9dcb6"), 10)
	for i in range(6):
		var hit := Rect2(origin + Vector2(i * (slot_size.x + gap), 0), slot_size)
		var rect := pressed_rect(hit, "select_" + str(i))
		var active := i == active_hotbar
		paper_panel(rect, Color("d9c79d") if active else Color("f0e5c6"), 8)
		if active: draw_rect(rect.grow(-1), Color("a9793d"), false, 3)
		label_at(rect.position + Vector2(5, 15), str(i + 1), 13, Color("68755e"))
		var item := bag.item_by_uid(hotbar[i])
		if not item.is_empty():
			draw_item_icon(str(item.id), Rect2(rect.position + Vector2(10, 8), Vector2(38, 37)))
			if item.has("durability"):
				var maximum := maxi(1, int(Data.info(item.id).get("durability", 1)))
				var width := 42.0 * float(item.durability) / maximum
				draw_rect(Rect2(rect.position + Vector2(8, 51), Vector2(42, 3)), Color("81775f"))
				if width > 0: draw_rect(Rect2(rect.position + Vector2(8, 51), Vector2(width, 3)), Color("617e56"))
		buttons.append({"rect": hit, "id": "select_" + str(i)})

func draw_wrapped_text(value: String, origin: Vector2, max_width: float, size: int = 16, max_lines: int = 4) -> void:
	var words := value.split(" ", false)
	var line := ""
	var y := origin.y
	var lines := 0
	for word in words:
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_width and not line.is_empty():
			label_at(Vector2(origin.x, y), line, size, Color("637057"))
			y += size + 6
			lines += 1
			line = word
			if lines >= max_lines: return
		else:
			line = candidate
	if not line.is_empty() and lines < max_lines: label_at(Vector2(origin.x, y), line, size, Color("637057"))

func ingredient_summary(cost: Dictionary) -> String:
	var parts := PackedStringArray()
	for id in cost: parts.append(Data.label(id) + " x" + str(cost[id]))
	return "  +  ".join(parts)

func draw_backpack_panel(base: Vector2) -> void:
	label_at(base + Vector2(28, 45), "BACKPACK   %d / %d SLOTS" % [bag.used_slots(), bag.slots.size()], 25)
	label_at(base + Vector2(28, 70), "Drag to move. Right-click to equip. Select an item, then press 1-6 to assign it.", 15, Color("657259"))
	for i in range(bag.slots.size()):
		draw_item_slot(bag_slot_rect(i), bag.slots[i], i == selected_slot)
	label_at(base + Vector2(29, 359), "QUICK TOOLBAR   Drag an item here or select it and press a number", 15, Color("657259"))
	for i in range(6):
		var rect := bag_hotbar_rect(i)
		var item := bag.item_by_uid(hotbar[i])
		draw_item_slot(rect, item, i == active_hotbar, i)
		buttons.append({"rect": rect, "id": "assign_" + str(i)})
	var detail_x := base.x + 625
	var detail_y := base.y + 106
	var selected: Dictionary = bag.slots[selected_slot] if selected_slot >= 0 and selected_slot < bag.slots.size() else {}
	label_at(Vector2(detail_x, detail_y), "ITEM DETAILS", 17, Color("657259"))
	if selected.is_empty():
		label_at(Vector2(detail_x, detail_y + 44), "Choose an item to see its use.", 16)
	else:
		draw_item_icon(str(selected.id), Rect2(detail_x, detail_y + 20, 58, 58))
		label_at(Vector2(detail_x + 68, detail_y + 42), Data.label(selected.id), 19)
		label_at(Vector2(detail_x + 68, detail_y + 66), "Quantity: " + str(selected.qty), 15, Color("657259"))
		draw_wrapped_text(str(Data.info(selected.id).get("description", "")), Vector2(detail_x, detail_y + 98), 270, 15, 5)
		if selected.has("fuel"):
			label_at(Vector2(detail_x, detail_y + 190), "Fuel: %d / 120 s  |  T toggles light" % ceili(float(selected.fuel)), 14)
		if selected.has("durability"):
			label_at(Vector2(detail_x, detail_y + 190), "Durability: %d / %d" % [int(selected.durability), int(Data.info(selected.id).durability)], 15)
		ui_button(Rect2(detail_x, base.y + 340, 125, 40), "Sort bag", "sort")
		ui_button(Rect2(detail_x + 138, base.y + 340, 125, 40), "Drop stack", "drop_selected")
		var repair_ready := selected.has("durability") and int(selected.durability) < int(Data.info(selected.id).durability) and nearby_bench() >= 0
		ui_button(Rect2(detail_x, base.y + 388, 263, 40), "Repair selected tool", "repair", repair_ready)
	label_at(Vector2(detail_x, base.y + 450), "Repair cost: 2 branches, 1 rock, 1 fiber.", 14, Color("657259"))
	ui_button(Rect2(base + Vector2(28, 492), Vector2(165, 40)), "B / Esc  Close", "close")

func draw_crafting_panel(base: Vector2) -> void:
	var at_bench := bench_available()
	label_at(base + Vector2(28, 45), "CRAFTING  ·  " + ("WORKBENCH" if at_bench else "FIELD RECIPES"), 25)
	label_at(base + Vector2(28, 72), "Choose a recipe. Materials are only used when there is room for the result.", 15, Color("657259"))
	var recipes := visible_recipes()
	var pages := maxi(1, ceili(float(recipes.size()) / 6.0))
	crafting_page = clampi(crafting_page, 0, pages - 1)
	for row in range(6):
		var index := crafting_page * 6 + row
		if index >= recipes.size(): break
		var recipe_index := recipes[index]
		var recipe: Dictionary = Data.RECIPES[recipe_index]
		var y := base.y + 101 + row * 56
		draw_item_icon(str(recipe.id), Rect2(base.x + 30, y + 3, 42, 42))
		label_at(Vector2(base.x + 83, y + 19), Data.label(recipe.id), 18)
		label_at(Vector2(base.x + 83, y + 41), ingredient_summary(recipe.cost), 14, Color("657259"))
		var can_make: bool = bag.can_pay(recipe.cost) and (bag.used_slots() < bag.slots.size() or not str(recipe.get("upgrade", "")).is_empty())
		ui_button(Rect2(base.x + 760, y + 3, 130, 42), "Craft  " + str(index + 1), "craft_" + str(recipe_index), can_make)
	if not at_bench:
		label_at(base + Vector2(30, 447), "Workbench recipes include a pickaxe, fishing rod and iron axe.", 15, Color("657259"))
	else:
		label_at(base + Vector2(30, 447), "Workbench: craft advanced tools, upgrade gear or repair the selected tool.", 15, Color("657259"))
	if pages > 1:
		ui_button(Rect2(base + Vector2(565, 485), Vector2(145, 40)), "Previous", "previous_page", crafting_page > 0)
		label_at(base + Vector2(720, 511), "Page %d / %d" % [crafting_page + 1, pages], 15)
		ui_button(Rect2(base + Vector2(790, 485), Vector2(100, 40)), "Next", "next_page", crafting_page + 1 < pages)
	ui_button(Rect2(base + Vector2(28, 492), Vector2(165, 40)), "C / Esc  Close", "close")

func draw_ore_node(index: int) -> void:
	if index < 0 or index >= ore_veins.size() or utility_props.size() < 6: return
	var vein: Dictionary = ore_veins[index]
	var tint := Color(0.84, 0.91, 0.88) if vein.depleted else Color.WHITE
	paint_model(model_spec("ore", vein.p, index), tint)

func draw_workbench(index: int) -> void:
	if index < 0 or index >= workbenches.size() or utility_props.is_empty(): return
	paint_model(model_spec("bench", workbenches[index].p, index))


func setup_mobile() -> void:
	mobile.enabled=OS.has_feature("mobile") or "--touch" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		mobile.enabled=bool(JavaScriptBridge.eval("matchMedia('(pointer:coarse)').matches || navigator.maxTouchPoints > 0 || new URLSearchParams(location.search).get('touch') === '1'"))
		browser_callback=JavaScriptBridge.create_callback(_browser_state)
		JavaScriptBridge.get_interface("window").forestGameState=browser_callback
		# The web shell combines focus, visibility, safe-area resize and orientation.

func _browser_state(args:Array) -> void:
	browser_suspended=bool(args[0]) if not args.is_empty() else true
	clear_mobile_input()

func clear_mobile_input() -> void:
	mobile.clear();menu_finger=-1;drag_slot=-1;moving=false;cancel_action()

func _notification(what:int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT or what==NOTIFICATION_APPLICATION_PAUSED:
		browser_suspended=true;clear_mobile_input()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN or what==NOTIFICATION_APPLICATION_RESUMED:
		browser_suspended=false;clear_mobile_input()
	elif what==NOTIFICATION_WM_SIZE_CHANGED:
		clear_mobile_input()

func mobile_action(id:String) -> void:
	if browser_suspended:return
	if id=="interact":interact();return
	if id=="use":use_selected();return
	if id.begins_with("slot_"):
		active_hotbar=clampi(int(id.trim_prefix("slot_")),0,5);cancel_action();return
	if id=="sprint":
		mobile_sprint=not mobile_sprint and not stamina_exhausted;mobile_sprint_used=false;return
	if id=="map":
		map_open=not map_open;return
	clear_mobile_input()
	match id:
		"bag":inventory=not inventory;crafting=false
		"craft":crafting=not crafting;inventory=false;crafting_page=0;crafting_station=nearby_bench()
		"torch":toggle_torch()
		"heal":use_medicine()
		"pause":paused=not paused

func draw_sanity_mark(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var angle: float = TAU*i/18.0
		points.append(center+Vector2(cos(angle),sin(angle))*radius*(0.91+0.08*sin(i*2.3)))
	draw_polyline(points,Color("827b9e"),2.5,true)
	draw_arc(center+Vector2(2,-1),radius*0.45,0.3,4.7,12,Color("827b9e"),2.3,true)
