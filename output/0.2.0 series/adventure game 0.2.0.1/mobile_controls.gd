extends RefCounted
# Touch input has explicit finger ownership. A held movement finger never becomes
# a click in an inventory opened by a second finger.
const MIN_TARGET := 82.0
const SAFE_SIDE := 100.0
const SAFE_BOTTOM := 72.0
const STICK_RADIUS := 94.0
const STICK_TRAVEL := 64.0
const DEADZONE := 0.18
const INK := Color("35483d")
const TEAL := Color("416c65")
const PAPER := Color("e9dcb6")
const LIGHT_PAPER := Color("f0e5c6")
const GOLD := Color("a9793d")

var enabled: bool = false
# Measured CSS canvas height, supplied by the browser host. Toolbar chrome can
# reduce it below390; targets then grow to retain a44CSS-pixel touch area.
var css_height: float = 390.0
var _last_css_height: float = -1.0
var interact_held: bool = false
var use_held: bool = false
var hit_regions: Dictionary = {}
var _owners: Dictionary = {}
var _inside: Dictionary = {}
var _suppressed: Dictionary = {}
var _joystick_id: int = -1
var _direction := Vector2.ZERO
var _thumb := Vector2.ZERO
var _screen := Vector2.ZERO
var _layout: Dictionary = {}

# Public and deterministic so target geometry can be checked without a renderer.
static func layout_for_size(screen: Vector2, css_view_height: float = 390.0) -> Dictionary:
	var regions: Dictionary = {}
	var target := maxf(MIN_TARGET, ceil(44.0 * screen.y / maxf(1.0, css_view_height)))
	var right := screen.x - SAFE_SIDE
	var bottom := screen.y - SAFE_BOTTOM
	var joystick := Vector2(SAFE_SIDE + STICK_RADIUS, bottom - STICK_RADIUS)
	var use_size := maxf(116.0, target)
	var gather_size := maxf(104.0, target)
	regions["joystick"] = Rect2(joystick - Vector2.ONE * STICK_RADIUS, Vector2.ONE * STICK_RADIUS * 2.0)
	regions["use"] = Rect2(Vector2(right - use_size, bottom - use_size), Vector2.ONE * use_size)
	regions["interact"] = Rect2(Vector2(right - use_size - 8.0 - gather_size, bottom - gather_size), Vector2.ONE * gather_size)
	var utility_gap := 10.0
	var utilities := Vector2(right - target * 3.0 - utility_gap * 2.0, bottom - use_size - 12.0 - target)
	for i in range(3):
		regions[["bag", "craft", "torch"][i]] = Rect2(utilities + Vector2(i * (target + utility_gap), 0), Vector2.ONE * target)
	regions["heal"] = Rect2(utilities + Vector2(target + utility_gap, -target - 12), Vector2.ONE * target)
	regions["pause"] = Rect2(utilities + Vector2((target + utility_gap) * 2, -target - 12), Vector2.ONE * target)
	regions["map"] = Rect2(utilities + Vector2(0, -target - 12), Vector2.ONE * target)
	# Run sits beside the stick so a thumb can slide over without a second hand.
	regions["sprint"] = Rect2(Vector2(joystick.x + STICK_RADIUS + 18.0, bottom - target), Vector2.ONE * target)
	var bar_width := target * 6.0 + 40.0
	var lower_slots_fit: bool = screen.x >= 1320 and (screen.x + bar_width) * 0.5 + 24 <= regions.interact.position.x and (screen.x - bar_width) * 0.5 >= regions.joystick.end.x + 24
	var slot_y := bottom - target if lower_slots_fit else 160.0
	var slot_start := Vector2((screen.x - bar_width) * 0.5, slot_y)
	for i in range(6):
		regions["slot_" + str(i)] = Rect2(slot_start + Vector2(i * (target + 8), 0), Vector2.ONE * target)
	return {"regions": regions, "joystick_center": joystick, "slots_at_top": not lower_slots_fit, "min_target": target}

func direction() -> Vector2:
	return _direction if enabled else Vector2.ZERO

func clear() -> void:
	# Keep canceled IDs until their release; the next press can reuse the same ID.
	for finger in _owners:
		_suppressed[finger] = true
	_owners.clear()
	_inside.clear()
	_joystick_id = -1
	_direction = Vector2.ZERO
	_thumb = Vector2.ZERO
	interact_held = false
	use_held = false

func _can_control(game: Variant, screen: Vector2) -> bool:
	return enabled and screen.x > screen.y and not game.inventory and not game.crafting and not game.paused and str(game.dialog).is_empty() and game.active_exploration()

func _prepare(game: Variant) -> bool:
	var size: Vector2 = game.get_viewport_rect().size
	if size != _screen or not is_equal_approx(css_height, _last_css_height):
		clear()
		_screen = size
		_last_css_height = css_height
		_layout = layout_for_size(size, css_height)
		hit_regions = _layout.regions
	if not _can_control(game, size):
		clear()
		return false
	return true

func _refresh_holds() -> void:
	interact_held = false
	use_held = false
	for finger in _owners:
		if not bool(_inside.get(finger, false)): continue
		if _owners[finger] == "interact": interact_held = true
		if _owners[finger] == "use": use_held = true

func _update_stick(position: Vector2) -> void:
	var offset := position - Vector2(_layout.joystick_center)
	_thumb = offset.limit_length(STICK_TRAVEL)
	var raw := _thumb / STICK_TRAVEL
	var magnitude := raw.length()
	_direction = Vector2.ZERO if magnitude <= DEADZONE else raw.normalized() * ((magnitude - DEADZONE) / (1.0 - DEADZONE))

func _release(finger: int) -> void:
	_owners.erase(finger)
	_inside.erase(finger)
	if finger == _joystick_id:
		_joystick_id = -1
		_direction = Vector2.ZERO
		_thumb = Vector2.ZERO
	_refresh_holds()

func handle_event(event: InputEvent, game: Variant) -> bool:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return false
	var finger: int = event.index
	if event is InputEventScreenTouch and event.pressed:
		_suppressed.erase(finger)
	elif _suppressed.has(finger):
		if event is InputEventScreenTouch: _suppressed.erase(finger)
		return true
	if not _prepare(game):
		if _suppressed.has(finger):
			if event is InputEventScreenTouch and not event.pressed: _suppressed.erase(finger)
			return true
		return false
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if not _owners.has(finger): return false
			_release(finger)
			return true
		# A second press for an owned ID cancels its old hold before reusing it.
		if _owners.has(finger): _release(finger)
		for name in hit_regions:
			var region: Rect2 = hit_regions[name]
			if not region.has_point(event.position): continue
			if name == "joystick":
				_owners[finger] = "joystick" if _joystick_id < 0 else "reserved"
				if _joystick_id < 0:
					_joystick_id = finger
					_update_stick(event.position)
				return true
			game.press_feedback("select_" + name.trim_prefix("slot_") if name.begins_with("slot_") else "m_" + name)
			var already_held := interact_held if name == "interact" else use_held if name == "use" else false
			_owners[finger] = name
			_inside[finger] = true
			_refresh_holds()
			if not already_held:
				game.mobile_action(str(name))
			# Opening any panel cancels both hands immediately, not a frame later.
			if not _can_control(game, _screen): clear()
			return true
		return false
	if not _owners.has(finger): return false
	var action: String = str(_owners[finger])
	if action == "joystick" and finger == _joystick_id:
		_update_stick(event.position)
	elif action == "interact" or action == "use":
		_inside[finger] = Rect2(hit_regions[action]).grow(18).has_point(event.position)
		_refresh_holds()
	return true

func _circle(game: Variant, center: Vector2, radius: float, color: Color) -> void:
	if game.has_method("record_draw_circle"): game.record_draw_circle(center, radius, color)
	else: game.draw_circle(center, radius, color, true, -1, true)

func _rect(game: Variant, rect: Rect2, color: Color) -> void:
	if game.has_method("record_draw_rect"): game.record_draw_rect(rect, color)
	else: game.draw_rect(rect, color, true, -1, false)

func _polygon(game: Variant, points: PackedVector2Array, color: Color) -> void:
	if game.has_method("record_draw_colored_polygon"): game.record_draw_colored_polygon(points, color)
	else: game.draw_colored_polygon(points, color)

func _line(game: Variant, a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if game.has_method("record_draw_line"): game.record_draw_line(a, b, color, width, true)
	else: game.draw_line(a, b, color, width, true)

func _center_label(game: Variant, center: Vector2, text: String, size: int, color := INK) -> void:
	var font: Font = game.get("font")
	if font == null: font = ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	game.label_at(center - Vector2(width * 0.5, 0), text, size, color)

func _held(name: String) -> bool:
	for finger in _owners:
		if _owners[finger] == name and bool(_inside.get(finger, true)): return true
	return false

func _paint_panel(game: Variant, rect: Rect2, active: bool, primary: bool = false) -> void:
	var color := Color("c3c4a0") if active else PAPER if primary else LIGHT_PAPER
	game.paper_panel(rect, color, 22 if primary else 15)
	# Fixed, broad pigment marks retain the existing hand-painted UI vocabulary.
	_rect(game, Rect2(rect.position + Vector2(11, 8), Vector2(rect.size.x * 0.38, 3)), Color(1.0, 0.98, 0.82, 0.24))
	_rect(game, Rect2(rect.end - Vector2(rect.size.x * 0.36 + 10, 9), Vector2(rect.size.x * 0.36, 2)), Color(0.38, 0.43, 0.28, 0.14))

func _bag_icon(game: Variant, center: Vector2) -> void:
	game.paper_panel(Rect2(center - Vector2(16, 15), Vector2(32, 33)), TEAL, 9)
	_line(game, center + Vector2(-9, -16), center + Vector2(-8, -22), INK, 3)
	_line(game, center + Vector2(-8, -22), center + Vector2(8, -22), INK, 3)
	_line(game, center + Vector2(8, -22), center + Vector2(9, -16), INK, 3)
	_rect(game, Rect2(center + Vector2(-11, 2), Vector2(22, 8)), Color("82937c"))

func _active_item(game: Variant) -> Dictionary:
	var slots: Array = game.hotbar
	var index: int = game.active_hotbar
	if index < 0 or index >= slots.size(): return {}
	return game.bag.item_by_uid(slots[index])

func _draw_button(game: Variant, name: String, title: String, icon: String = "", primary: bool = false) -> void:
	var rect: Rect2 = game.pressed_rect(hit_regions[name], "m_" + name, _held(name))
	_paint_panel(game, rect, _held(name) or (name == "sprint" and bool(game.mobile_sprint)), primary)
	var center := rect.get_center()
	var icon_size := 44.0 if primary else 36.0
	var icon_center := Vector2(center.x, rect.position.y + rect.size.y * 0.36)
	if name == "bag": _bag_icon(game, icon_center)
	elif name == "map":
		_rect(game, Rect2(icon_center + Vector2(-15, -13), Vector2(30, 26)), Color("c9b98a"))
		_line(game, icon_center + Vector2(-15, -13), icon_center + Vector2(-15, 13), TEAL, 3)
		_line(game, icon_center + Vector2(-5, -13), icon_center + Vector2(-5, 13), Color(0.25, 0.42, 0.39, 0.55), 2)
		_line(game, icon_center + Vector2(5, -13), icon_center + Vector2(5, 13), Color(0.25, 0.42, 0.39, 0.55), 2)
		_circle(game, icon_center + Vector2(9, -2), 4, Color("b7674c"))
	elif name == "sprint":
		_line(game, icon_center + Vector2(-14, 8), icon_center + Vector2(4, 8), TEAL, 5)
		_line(game, icon_center + Vector2(-10, -2), icon_center + Vector2(8, -2), TEAL, 5)
		_line(game, icon_center + Vector2(-6, -12), icon_center + Vector2(12, -12), TEAL, 5)
		_line(game, icon_center + Vector2(6, 8), icon_center + Vector2(14, -2), GOLD, 4)
	elif name == "pause":
		_rect(game, Rect2(icon_center + Vector2(-12, -15), Vector2(7, 29)), TEAL)
		_rect(game, Rect2(icon_center + Vector2(5, -14), Vector2(7, 29)), TEAL)
	elif not icon.is_empty():
		game.draw_item_icon(icon, Rect2(icon_center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size))
	else:
		# Empty hands use a quiet brush-stroke mark instead of a made-up weapon.
		_line(game, icon_center + Vector2(-12, 11), icon_center + Vector2(12, -12), TEAL, 7)
		_line(game, icon_center + Vector2(-10, -2), icon_center + Vector2(1, 9), TEAL.lightened(0.14), 5)
	_center_label(game, Vector2(center.x, rect.end.y - 12), title, 28 if primary else 24)

func draw(game: Variant) -> void:
	if not _prepare(game): return
	var center: Vector2 = _layout.joystick_center
	_circle(game, center + Vector2(0, 4), STICK_RADIUS + 3, Color(0.05, 0.13, 0.12, 0.18))
	var rim := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		var radius := STICK_RADIUS + sin(i * 2.31) * 1.7
		rim.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_polygon(game, rim, Color(0.83, 0.83, 0.66, 0.69))
	_circle(game, center, STICK_RADIUS - 7, Color(0.16, 0.34, 0.31, 0.52))
	_circle(game, center + Vector2(-18, -19), 36, Color(0.62, 0.73, 0.60, 0.10))
	_circle(game, center + _thumb + Vector2(0, 3), 39, Color(0.06, 0.15, 0.12, 0.25))
	_circle(game, center + _thumb, 38, Color("ddcfaa"))
	_circle(game, center + _thumb + Vector2(-9, -10), 19, Color(0.98, 0.94, 0.77, 0.30))
	_center_label(game, center + Vector2(0, 76), "MOVE", 22, Color("f0e5c6"))
	_draw_button(game, "interact", "Gather", "branch", true)
	var selected := _active_item(game)
	_draw_button(game, "use", "Use", str(selected.get("id", "")), true)
	_draw_button(game, "bag", "Bag")
	_draw_button(game, "craft", "Craft", "stone_axe")
	_draw_button(game, "torch", "Torch", "torch")
	_draw_button(game, "heal", "Heal", "medicine")
	_draw_button(game, "pause", "Pause")
	_draw_button(game, "map", "Map")
	var running: bool = bool(game.mobile_sprint) or bool(game.sprinting)
	_draw_button(game, "sprint", "Run ON" if running else "Run")
	if running:
		var ring: Rect2 = game.pressed_rect(hit_regions["sprint"], "m_sprint")
		game.draw_rect(ring.grow(3), GOLD, false, 4.0)
	for i in range(6):
		var rect: Rect2 = game.pressed_rect(hit_regions["slot_" + str(i)], "select_" + str(i), _held("slot_" + str(i)))
		var active: bool = i == game.active_hotbar
		_paint_panel(game, rect, active)
		if active:
			_rect(game, Rect2(rect.position + Vector2(10, 3), Vector2(rect.size.x - 20, 3)), GOLD)
		var item: Dictionary = game.bag.item_by_uid(game.hotbar[i])
		if not item.is_empty():
			game.draw_item_icon(str(item.id), Rect2(rect.position + Vector2((rect.size.x - 54) * 0.5, 9), Vector2(54, 54)))
			if int(item.get("qty", 1)) > 1:
				game.label_at(rect.position + Vector2(rect.size.x - 28, 68), str(item.qty), 18, INK)
		game.label_at(rect.position + Vector2(8, 20), str(i + 1), 18, Color("766b4c"))
		if active: _center_label(game, Vector2(rect.get_center().x, rect.end.y - 6), "READY", 16, INK)
