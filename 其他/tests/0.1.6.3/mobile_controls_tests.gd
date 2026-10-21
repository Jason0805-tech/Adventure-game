extends SceneTree
const Controls = preload("res://mobile_controls.gd")
class FakeGame:
	extends RefCounted
	var size := Vector2(1518, 720)
	var inventory := false
	var crafting := false
	var paused := false
	var dialog := ""
	var playing := true
	var actions: Array[String] = []
	var open_panels := false
	func get_viewport_rect() -> Rect2: return Rect2(Vector2.ZERO, size)
	func active_exploration() -> bool: return playing
	func mobile_action(action: String) -> void:
		actions.append(action)
		if open_panels:
			if action == "bag": inventory = true
			if action == "craft": crafting = true
			if action == "pause": paused = true

var checks := 0
var failures: Array[String] = []
func check(value: bool, text: String) -> void:
	checks += 1
	if not value: failures.append(text); push_error(text)
func touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index; event.position = position; event.pressed = pressed; event.canceled = canceled
	return event
func drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index; event.position = position
	return event
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for width in [960, 1080, 1319, 1320, 1518, 1558, 1920]:
		var layout: Dictionary = Controls.layout_for_size(Vector2(width, 720))
		var regions: Dictionary = layout.regions
		check(regions.size() == 14, "14 independent touch targets at " + str(width))
		var keys: Array = regions.keys()
		for i in range(keys.size()):
			var r: Rect2 = regions[keys[i]]
			check(r.size.x >= 82 and r.size.y >= 82, "44 CSS px minimum target " + str(keys[i]))
			check(r.position.x >= 99.9 and r.end.x <= width - 99.9, "side safe areas " + str(keys[i]))
			check(r.position.y >= 143 and r.end.y <= 648.1, "HUD and home indicator clearance " + str(keys[i]))
			for j in range(i + 1, keys.size()):
				check(not r.intersects(regions[keys[j]]), "targets cannot overlap " + str(keys[i]) + "/" + str(keys[j]))
		check(layout.slots_at_top == (width < 1320), "narrow landscape toolbar avoids primary controls")
	# Browser toolbars reduce CSS height while the virtual world stays720 high.
	for css_height in [300.0, 320.0, 390.0, 430.0]:
		for width in [960, 1080, 1320, 1518, 1920]:
			var adaptive: Dictionary = Controls.layout_for_size(Vector2(width, 720), css_height)
			var regions: Dictionary = adaptive.regions
			var keys: Array = regions.keys()
			for i in range(keys.size()):
				var rect: Rect2 = regions[keys[i]]
				check(rect.size.x * css_height / 720.0 >= 43.999 and rect.size.y * css_height / 720.0 >= 43.999, "CSS touch target44px at height" + str(css_height))
				for j in range(i + 1, keys.size()):
					check(not rect.intersects(regions[keys[j]]), "adaptive targets separated height" + str(css_height) + ":" + str(keys[i]) + "/" + str(keys[j]))
	check(Controls.layout_for_size(Vector2(1518,720),320).min_target == 99, "Safari320px CSS height needs99px virtual target")
	var game := FakeGame.new()
	var c = Controls.new()
	var layout: Dictionary = Controls.layout_for_size(game.size)
	var regions: Dictionary = layout.regions
	var center: Vector2 = layout.joystick_center
	check(not c.handle_event(touch(0, center, true), game), "disabled ignores new touch")
	c.enabled = true
	check(c.handle_event(touch(0, center + Vector2(2, 2), true), game), "joystick captures finger")
	check(c.direction() == Vector2.ZERO, "joystick central dead zone")
	check(c.handle_event(drag(0, center + Vector2(180, -180)), game), "joystick drag owned beyond bounds")
	check(c.direction().distance_to(Vector2(1, -1).normalized()) < 0.00001, "diagonal normalized cap")
	check(c.direction().length() <= 1.00001, "never moves faster on a diagonal")
	check(c.handle_event(touch(1, regions.use.get_center(), true), game), "attack second finger accepted")
	check(c.use_held and not c.interact_held and c.direction().length() > .99, "moving and attacking concurrently")
	check(game.actions == ["use"], "tool action fires once at press")
	c.handle_event(drag(0, center + Vector2(-64, 0)), game)
	check(c.direction().x < -.99 and c.use_held, "attack finger cannot steal movement")
	c.handle_event(touch(2, regions.use.get_center(), true), game)
	check(game.actions.size() == 1 and c.use_held, "second attack finger does not double initial strike")
	c.handle_event(touch(1, Vector2.ZERO, false), game)
	check(c.use_held, "one attack finger release preserves other held attack")
	c.handle_event(drag(2, Vector2(759, 300)), game)
	check(not c.use_held, "drag away cancels held attack")
	c.handle_event(drag(2, regions.use.get_center()), game)
	check(c.use_held and game.actions.size() == 1, "reenter resumes hold without extra press")
	c.handle_event(touch(2, regions.use.get_center(), false, true), game)
	check(not c.use_held and c.direction().x < -.99, "system cancellation clears only its finger")
	c.handle_event(touch(3, regions.interact.get_center(), true), game)
	check(c.interact_held and game.actions.back() == "interact", "Gather action and held flag")
	c.handle_event(touch(4, center + Vector2(0, 50), true), game)
	check(c.direction().x < -.99, "second joystick finger cannot steal first")
	c.handle_event(touch(4, center, false), game)
	check(c.direction().x < -.99, "second joystick release cannot stop first")
	check(not c.handle_event(touch(9, Vector2(759, 300), true), game), "world touch stays available to game")
	c.clear()
	check(c.direction() == Vector2.ZERO and not c.interact_held and not c.use_held, "clear cancels all actions")
	check(c.handle_event(drag(0, Vector2(900, 400)), game), "canceled joystick cannot drag inventory")
	check(c.handle_event(touch(0, Vector2(900, 400), false), game), "canceled old release consumed")
	check(not c.handle_event(drag(0, Vector2(900, 400)), game), "quarantine ends at release")
	c.handle_event(touch(0, center, true), game)
	c.handle_event(drag(0, center + Vector2(50, 0)), game)
	check(c.direction().x > .7, "finger ID can be reused after clear")
	game.open_panels = true
	c.handle_event(touch(1, regions.bag.get_center(), true), game)
	check(game.inventory and game.actions.back() == "bag", "bag utility opens bag")
	check(c.direction() == Vector2.ZERO and not c.use_held and not c.interact_held, "opening menu synchronously cancels all holds")
	check(c.handle_event(drag(0, Vector2(600, 400)), game), "old movement cannot act on open menu")
	check(c.handle_event(touch(1, regions.bag.get_center(), false), game), "opening utility release does not click menu")
	check(not c.handle_event(touch(7, Vector2(759, 300), true), game), "new menu finger delegated to existing UI")
	game.inventory = false
	c.handle_event(touch(0, center + Vector2(50, 0), true), game)
	c.handle_event(touch(1, regions.use.get_center(), true), game)
	game.crafting = true
	check(c.handle_event(drag(0, center + Vector2(60, 0)), game), "external menu cancel still consumes the old drag")
	check(c.direction() == Vector2.ZERO and not c.use_held, "external menu cancels actions without waiting for draw")
	game.crafting = false
	c.handle_event(touch(0, center + Vector2(50, 0), true), game)
	game.size = Vector2(720, 1518)
	check(c.handle_event(drag(0, center), game), "portrait transition consumes old drag")
	check(c.direction() == Vector2.ZERO and not c.use_held, "portrait has no walking or attacking")
	check(not c.handle_event(touch(5, Vector2(300, 900), true), game), "portrait ignores new game controls")
	game.size = Vector2(1518, 720)
	c.handle_event(touch(0, center + Vector2(50, 0), true), game)
	c.css_height = 320
	c.handle_event(drag(0, center + Vector2(60, 0)), game)
	check(c.direction() == Vector2.ZERO and c.hit_regions.heal.size.x == 99, "CSS toolbar resize cancels gesture and grows targets")
	c.handle_event(touch(0, center + Vector2(50, 0), true), game)
	game.size = Vector2(1558, 720)
	c.handle_event(drag(0, center + Vector2(60, 0)), game)
	check(c.direction() == Vector2.ZERO, "landscape resize also cancels old gesture")
	for state in ["paused", "dialog", "playing"]:
		game.paused = false; game.dialog = ""; game.playing = true
		c.handle_event(touch(0, center + Vector2(50, 0), true), game)
		if state == "paused": game.paused = true
		elif state == "dialog": game.dialog = "Hello"
		else: game.playing = false
		c.handle_event(drag(0, center), game)
		check(c.direction() == Vector2.ZERO, state + " cancels touch movement")
	game.paused = false; game.dialog = ""; game.playing = true; game.open_panels = false
	for action in ["craft", "heal", "torch", "pause", "slot_0", "slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]:
		var rect: Rect2 = c.layout_for_size(game.size).regions[action]
		var before := game.actions.size()
		check(c.handle_event(touch(20, rect.get_center(), true), game), "button press " + action)
		c.handle_event(drag(20, Vector2(500, 400)), game)
		c.handle_event(touch(20, Vector2(500, 400), false), game)
		check(game.actions.size() == before + 1 and game.actions.back() == action, "button invokes exactly one action " + action)
	check(not c.handle_event(InputEventMouseButton.new(), game), "emulated mouse cannot trigger duplicate action")
	var result := {"checks": checks, "failures": failures, "passed": failures.is_empty(), "source_hashes":{"mobile_controls.gd":FileAccess.get_sha256("res://mobile_controls.gd")}, "sizes": [960,1080,1319,1320,1518,1558,1920]}
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var file := FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "\t"))
	print("MOBILE_CONTROLS_TESTS ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
