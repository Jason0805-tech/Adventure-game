extends SceneTree
# Actual release scene + Godot ScreenTouch/ScreenDrag events. This verifies game
# state, not Safari/WebGL or a physical iPhone. Runtime sources are never patched.
var game: Variant
var checks := 0
var failures: Array[String] = []
var scenarios: Array[String] = []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)

func touch(finger: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger; event.position = position
	event.pressed = pressed; event.canceled = canceled
	game._input(event)

func drag(finger: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger; event.position = position
	game._input(event)

func point(action: String) -> Vector2:
	return Rect2(game.mobile.hit_regions[action]).get_center()

func tick(count: int = 1, dt: float = 0.05) -> void:
	for i in range(count): game._process(dt)

func snapshot() -> Dictionary:
	return {
		"player":game.player, "elapsed":game.elapsed, "phase":game.phase,
		"day_time":game.day_time,"phase_time":game.phase_time,"night_elapsed":game.night_elapsed,
		"health":game.health,"fullness":game.fullness,"hunger_elapsed":game.hunger_elapsed,
		"torch_fuel":game.torch_fuel,"torch_item":game.bag.item_by_uid(game.torch_uid).duplicate(true),
		"npcs":game.npc_states.duplicate(true),"animals":game.wildlife.animals.duplicate(true),
		"animal_respawn":game.wildlife.respawn_in,"animal_hit_grace":game.wildlife.player_hit_grace,
		"animal_rng":game.wildlife.rng.state,"action":game.action.duplicate(true),
		"cooldown":game.interaction_cooldown,"walk_distance":game.walk_distance,
	}

func frozen(label: String) -> void:
	var before := snapshot()
	tick(20)
	var after := snapshot()
	for key in before:
		check(before[key] == after[key], label + " freezes " + str(key))

func cleared(label: String) -> void:
	check(game.mobile.direction() == Vector2.ZERO,label + " clears joystick")
	check(not game.mobile.use_held and not game.mobile.interact_held,label + " clears held actions")
	check(game.action.is_empty(),label + " cancels in-flight action")
	check(game.menu_finger == -1 and game.drag_slot == -1,label + " clears item drag ownership")

func open_route() -> Vector2:
	# Independently verify a real 54-unit legal road segment before testing speed.
	for y in range(720,821,10):
		for x in range(600,1501,60):
			var legal := true
			for step in range(55):
				if not game.walkable(Vector2(x+step,y)):
					legal = false; break
			if legal: return Vector2(x,y)
	return Vector2.INF

func reset_controls() -> void:
	game.inventory=false;game.crafting=false;game.dialog="";game.paused=false
	game.browser_suspended=false;game.clear_mobile_input();game.last_mobile_modal=false
	game.interaction_cooldown=0
	game._process(0)
	game.mobile._prepare(game)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var started := Time.get_ticks_usec()
	root.size=Vector2i(1518,720);root.content_scale_size=Vector2i(1518,720)
	game=load("res://main.gd").new();game.resource_seed=16331
	root.add_child(game);game.set_process(false)
	game.mobile.enabled=true
	game.phase="day";game.day_time=70;game.health=74;game.fullness=64
	reset_controls()
	check(game.get_viewport_rect().size==Vector2(1518,720),"actual landscape scene viewport")
	check(not game.wildlife.animals.is_empty(),"freeze checks include real spawned animals")
	check(game.npc_states.size()==2,"freeze checks include both real NPC states")
	game.bag.add("wood_sword",1)
	var sword: Dictionary=game.bag.slots[game.bag.first("wood_sword")]
	game.auto_equip(int(sword.uid))
	game.bag.add("torch",1);game.toggle_torch();game.interaction_cooldown=0
	check(game.torch_lit and game.torch_fuel==120,"fixture includes a real lit fuel-bearing torch")
	var start := open_route()
	check(start.is_finite(),"independent real-world legal movement segment exists")
	if not start.is_finite(): finish(started);return
	game.player=start
	var stick: Vector2=game.mobile._layout.joystick_center
	var full_right := stick+Vector2(64,0)
	touch(1,stick,true);drag(1,full_right)
	check(game.mobile.direction().is_equal_approx(Vector2.RIGHT),"actual touch drag reaches full joystick magnitude")
	tick(5)
	check(game.player.distance_to(start+Vector2(game.SPEED*0.25,0))<0.001,"real player advances at108world units/s along verified route")
	check(game.moving and game.walk_distance>0,"real movement advances walking animation by distance")
	touch(2,point("use"),true)
	check(game.mobile.use_held and not game.action.is_empty(),"second finger starts actual equipped sword action")
	check(game.mobile.direction().is_equal_approx(Vector2.RIGHT),"Use finger preserves movement owner")
	touch(2,point("use"),false)
	check(not game.mobile.use_held and game.mobile.direction().x>0.99,"release Use preserves held movement")
	tick(5)
	check(game.player.distance_to(start+Vector2(game.SPEED*0.5,0))<0.001,"movement continues after independent Use release")
	touch(1,full_right,false)
	var stopped: Vector2=game.player
	tick(2)
	check(game.player==stopped and game.mobile.direction()==Vector2.ZERO,"release joystick stops actual player")
	check(not game.moving,"released joystick stops real walking state")
	# Reverse release order: a canceled movement finger must not cancel held Use.
	game.interaction_cooldown=0;game.cancel_action()
	touch(1,stick,true);drag(1,full_right);touch(2,point("use"),true)
	touch(1,full_right,false,true)
	check(game.mobile.direction()==Vector2.ZERO and game.mobile.use_held,"canceled movement does not release attack finger")
	touch(2,point("use"),false,true)
	check(not game.mobile.use_held,"canceled Use releases attack")
	# Gather through the real inventory path, with a separate stationary stick.
	game.cancel_action();game.interaction_cooldown=0
	game.items.clear();game.add_item(game.player+Vector2(0,22),"branch")
	var branches: int=game.bag.count("branch")
	touch(10,stick,true);touch(11,point("interact"),true)
	check(game.bag.count("branch")==branches+1 and game.items[0].taken,"Gather finger collects the real staged resource")
	check(game.mobile.interact_held,"Gather maintains its own held finger")
	touch(10,stick,false)
	check(game.mobile.interact_held,"release movement preserves Gather hold")
	touch(11,point("interact"),false,true)
	check(not game.mobile.interact_held,"canceled Gather releases only its hold")
	scenarios.append("real movement speed, walking, independent Use/Gather fingers, both release orders and cancellation")
	# Bag opens while two gameplay fingers remain down. Their late up/drag events
	# cannot select/swap bag stacks or steal an independent menu drag finger.
	reset_controls()
	touch(1,stick,true);drag(1,full_right);touch(2,point("use"),true)
	touch(3,point("bag"),true)
	check(game.inventory,"Bag touch opens actual inventory")
	cleared("opening Bag")
	game._process(0)
	frozen("inventory")
	var slot: Vector2=game.bag_slot_rect(0).get_center()
	var second: Vector2=game.bag_slot_rect(1).get_center()
	touch(4,slot,true)
	check(game.menu_finger==4 and game.drag_slot==0,"new menu finger owns a real item drag")
	var before_slots: Array=game.bag.slots.duplicate(true)
	drag(1,second);touch(1,second,false);touch(2,second,false);touch(3,second,false)
	check(game.menu_finger==4 and game.drag_slot==0,"late gameplay releases cannot steal menu item drag")
	check(game.bag.slots==before_slots,"late gameplay drags cannot rearrange inventory")
	touch(5,second,true)
	check(game.menu_finger==4 and game.drag_slot==0,"second menu finger cannot hijack first item drag")
	touch(5,second,false)
	touch(4,slot,false,true)
	check(game.menu_finger==-1 and game.drag_slot==-1,"canceled menu touch clears item drag")
	check(game.bag.slots==before_slots,"canceling an item touch preserves bag contents")
	scenarios.append("bag full simulation freeze, modal finger quarantine, one menu drag owner and canceled inventory touch")
	# Every full-simulation pause must freeze actor animation, vitals and fuel.
	reset_controls();game.crafting=true;game._process(0);frozen("crafting")
	reset_controls();game.dialog="Rowan";game._process(0);frozen("conversation")
	reset_controls();touch(6,point("pause"),true)
	check(game.paused,"Pause touch activates actual manual pause")
	cleared("manual pause");frozen("manual pause")
	game._browser_state([true]);frozen("background while manually paused")
	game._browser_state([false])
	check(game.paused,"focus return preserves pre-existing manual pause")
	# Focus/hidden tab clears even a partly moved item drag and never catches up.
	reset_controls();touch(1,stick,true);drag(1,full_right);touch(2,point("use"),true)
	game._browser_state([true]);cleared("browser hide");frozen("browser hidden")
	touch(1,full_right,false);touch(2,point("use"),false)
	game._browser_state([false]);cleared("browser return")
	var return_elapsed: float=game.elapsed
	game._process(25.0)
	check(is_equal_approx(game.elapsed-return_elapsed,0.05),"long return delta cannot catch up hidden wall time")
	check(game.player==stopped,"focus return does not replay held joystick")
	game.inventory=true;game._process(0);touch(20,slot,true);drag(20,second)
	check(game.menu_finger==20 and game.drag_slot==0,"fixture contains an active inventory drag before blur")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	cleared("native focus loss");frozen("native focus lost")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.inventory,"native focus return preserves open inventory")
	touch(20,second,false)
	check(game.menu_finger==-1 and game.drag_slot==-1,"late inventory release after blur cannot revive drag")
	scenarios.append("craft/dialog/manual pause, background/native focus freeze, drag clearing, manual pause preservation and bounded return delta")
	# Actual viewport rotation blocks gameplay and invalidates contact ownership.
	reset_controls();touch(1,stick,true);drag(1,full_right);touch(2,point("use"),true)
	root.size=Vector2i(720,1100);root.content_scale_size=Vector2i(720,1100)
	await process_frame
	game.browser_suspended=false
	game._process(0)
	check(game.get_viewport_rect().size.x<game.get_viewport_rect().size.y,"actual viewport changed to portrait")
	cleared("portrait resize");frozen("portrait")
	touch(1,full_right,false);touch(2,Vector2(600,900),false)
	game.paused=true
	root.size=Vector2i(1518,720);root.content_scale_size=Vector2i(1518,720)
	await process_frame
	game.browser_suspended=false;game._process(0)
	check(game.paused,"landscape return preserves explicit manual pause")
	cleared("landscape return");frozen("landscape manual pause")
	scenarios.append("portrait full simulation freeze, rotation invalidates old fingers and landscape preserves manual pause")
	finish(started)

func finish(started: int) -> void:
	var result := {"checks":checks,"failures":failures,"passed":failures.is_empty(),
		"duration_seconds":(Time.get_ticks_usec()-started)/1000000.0,"scenarios":scenarios,
		"source_hashes":{"main.gd":FileAccess.get_sha256("res://main.gd"),"mobile_controls.gd":FileAccess.get_sha256("res://mobile_controls.gd"),"mobile_ui.gd":FileAccess.get_sha256("res://mobile_ui.gd")},
		"scope":"Actual Godot release scene with synthetic native touch/lifecycle events; no browser, GPU pixel capture or physical iPhone claim"}
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i]=="--result":
			var file := FileAccess.open(args[i+1],FileAccess.WRITE)
			file.store_string(JSON.stringify(result,"\t"))
	print("MOBILE_ACTUAL_INPUT_QA ",JSON.stringify(result))
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
