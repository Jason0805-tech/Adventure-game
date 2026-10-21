extends SceneTree
var checks:int=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->bool:
	checks+=1
	if ok:print("PASS ",label);return true
	push_error("FAIL "+label);quit(1);return false
func press(game:Variant,key:int)->void:
	var event:=InputEventKey.new()
	event.physical_keycode=key;event.pressed=true
	game._unhandled_key_input(event)
func clear_route(game:Variant)->Vector2:
	for y in range(300,1300,80):
		for x in range(220,1900,80):
			var p:=Vector2(x,y)
			var good:bool=true
			for i in range(43):
				if not game.walkable(p+Vector2(i*3,0)):good=false;break
			if good:return p
	return Vector2.ZERO
func run()->void:
	var game:Variant=load("res://main.tscn").instantiate()
	game.resource_seed=160
	root.add_child(game);game.set_process(false)
	await process_frame
	if not check(game.day_duration==180.0 and game.dusk_duration==6.0 and game.night_duration==90.0,"180-second day, six-second dusk and 90-second night defaults"):return
	if not check(game.phase=="day" and game.clock_text()=="03:00" and game.active_exploration(),"day begins with exploration and readable countdown"):return
	var origin:Vector2=clear_route(game)
	if not check(origin!=Vector2.ZERO,"continuous legal movement route exists"):return
	game.player=origin;game.day_time=179.5
	game.advance_day(0.5)
	if not check(game.phase=="dusk" and game.player==origin,"automatic dusk preserves world position and never teleports to camp"):return
	if not check(game.active_exploration() and game.wildlife_period()=="dusk" and game.clock_text()=="00:06","dusk remains playable and reports its six-second transition"):return
	game.advance_phase(3.0)
	if not check(game.phase=="dusk" and game.clock_text()=="00:03","dusk counts down without a night choice modal"):return
	game.advance_phase(3.0)
	if not check(game.phase=="night" and game.wildlife_period()=="night" and game.clock_text()=="01:30","night becomes free exploration with a 90-second dawn countdown"):return
	var down:=InputEventKey.new();down.physical_keycode=KEY_D;down.keycode=KEY_D;down.pressed=true
	Input.parse_input_event(down);Input.flush_buffered_events()
	for i in range(20):game._process(0.05)
	var up:=InputEventKey.new();up.physical_keycode=KEY_D;up.keycode=KEY_D;up.pressed=false
	Input.parse_input_event(up);Input.flush_buffered_events()
	print("NIGHT_INPUT_DIAGNOSTIC ",origin," -> ",game.player," distance=",game.player.distance_to(origin)," phase=",game.phase)
	if not check(absf(game.player.distance_to(origin)-108.0)<0.1,"actual night process accepts movement at 108 world units per second"):return
	if not check(game.night_elapsed>=0.99 and game.night_elapsed<1.01,"night simulation and movement consume the same elapsed second"):return
	game.bag.add("medicine",2);game.health=45.0
	var medicine_before:int=game.bag.count("medicine")
	press(game,KEY_H)
	if not check(game.health==85 and game.bag.count("medicine")==medicine_before-1,"H consumes medicine and heals during a real-time night"):return
	game.bag.add("fish",1)
	var fish_uid:int=int(game.bag.slots[game.bag.first("fish")].uid)
	game.auto_equip(fish_uid);game.fullness=50
	game.use_selected()
	if not check(game.fullness==75 and game.bag.count("fish")==0,"selected food can be consumed during nighttime exploration"):return
	game.bag.add("branch",2);game.bag.add("rock",3);game.bag.add("rope",1)
	game.craft_recipe(0)
	if not check(game.selected_item().get("id","")=="stone_axe","field crafting creates and equips an axe during nighttime"):return
	var harvest_tree:Vector2=Vector2.ZERO
	for tree in game.trees:
		for heading in range(16):
			var approach:Vector2=tree+Vector2.from_angle(heading*TAU/16)*54
			if game.walkable(approach):
				game.player=approach
				if game.target_line_clear(tree):harvest_tree=tree;break
		if harvest_tree!=Vector2.ZERO:break
	if not check(harvest_tree!=Vector2.ZERO,"legal unobstructed nighttime chopping approach exists"):return
	game.tree_states[harvest_tree].hp=1
	var axe_uid:int=int(game.selected_item().uid)
	var durability_before:int=int(game.bag.item_by_uid(axe_uid).durability)
	if not check(game.begin_action({"kind":"tree","pos":harvest_tree}),"axe begins a normal harvesting animation at night"):return
	game.update_action(0.20)
	if not check(not game.action.is_empty() and float(game.action.elapsed)>0 and game.tree_live(harvest_tree),"night harvesting animation advances before its contact frame"):return
	game.update_action(0.35);game.update_action(0.50)
	if not check(not game.tree_live(harvest_tree) and game.bag.count("log")>=4,"night action contact fells a tree and gives its normal materials"):return
	if not check(game.action.is_empty() and int(game.bag.item_by_uid(axe_uid).durability)==durability_before-1,"night harvesting finishes once and consumes one tool durability"):return
	press(game,KEY_3)
	if not check(game.active_hotbar==2,"hotbar selection remains available at night"):return
	press(game,KEY_B)
	if not check(game.inventory,"night backpack opens through real keyboard input"):return
	var elapsed_before:float=game.elapsed
	var night_before:float=game.night_elapsed
	var hunger_before:float=game.hunger_elapsed
	game._process(1.0);game.advance_phase(20.0);game.advance_vitals(20.0)
	if not check(game.elapsed==elapsed_before and game.night_elapsed==night_before and game.hunger_elapsed==hunger_before,"backpack freezes world simulation, night clock and hunger together"):return
	press(game,KEY_ESCAPE)
	if not check(not game.inventory and not game.paused,"Escape closes bag without silently leaving game paused"):return
	press(game,KEY_C)
	if not check(game.crafting,"crafting remains available during night"):return
	game._process(1.0);game.advance_phase(20.0)
	if not check(game.night_elapsed==night_before,"crafting freezes the night clock and animal simulation"):return
	press(game,KEY_ESCAPE)
	game.dialog="Rowan\nTest conversation"
	game._process(1.0);game.advance_phase(20.0)
	if not check(game.night_elapsed==night_before,"conversation freezes the same survival clock"):return
	press(game,KEY_E)
	if not check(game.dialog.is_empty(),"night conversation closes through normal E input"):return
	press(game,KEY_ESCAPE)
	if not check(game.paused,"Escape pauses free night exploration"):return
	game._process(1.0);game.advance_phase(20.0)
	if not check(game.night_elapsed==night_before,"pause cannot advance toward safe dawn"):return
	press(game,KEY_ESCAPE)
	game.fullness=1;game.hunger_elapsed=0;game.health=100
	game.advance_vitals(20)
	if not check(game.fullness==0 and absf(game.health-95.0)<0.001,"night hunger and starvation damage use the same continuous rules as daylight"):return
	game.fullness=100;game.hunger_elapsed=0;game.health=92
	game.night_elapsed=89.5;game.phase_time=89.5
	var power_before:int=game.power
	medicine_before=game.bag.count("medicine")
	var crystal_before:int=game.bag.count("crystal")
	game.resolve_night()
	if not check(game.phase=="night" and game.survived==0,"calling legacy resolution cannot skip an unfinished real-time night"):return
	game.advance_phase(0.5)
	if not check(game.phase=="result" and game.survived==1 and not game.active_exploration(),"dawn records the first survival exactly at the real-time boundary"):return
	if not check(game.health==92 and game.power==power_before and game.bag.count("medicine")==medicine_before and game.bag.count("crystal")==crystal_before,"dawn performs no abstract power damage or automatic consumable spending"):return
	if not check(game.wildlife_period()=="day" and game.clock_text()=="00:00","dawn synchronizes day-only wildlife and stops night countdown"):return
	game.resolve_night();game.advance_phase(1000);game.choose_action(0)
	if not check(game.survived==1 and game.phase=="result","duplicate callbacks and legacy choice cannot grant extra survived nights"):return
	var dawn_position:Vector2=game.player
	press(game,KEY_ENTER)
	if not check(game.phase=="day" and game.night==2 and game.clock_text()=="03:00" and game.player==dawn_position,"Enter starts day two at current position with a full daylight timer"):return
	game.inventory=true;game.advance_day(30)
	if not check(game.day_time==0,"daylight also freezes in menus for a consistent simulation policy"):return
	game.inventory=false
	game.advance_day(180);game.advance_phase(96)
	if not check(game.phase=="result" and game.survived==2,"second free night can reach dawn and awards one survival"):return
	game.next_day();game.advance_day(180);game.advance_phase(96)
	if not check(game.won and game.phase=="won" and game.survived==3 and not game.active_exploration(),"third survived night ends the run with the three-night victory"):return
	var winning_health:float=game.health
	game.take_damage(1000);game.next_day();game.resolve_night()
	if not check(game.health==winning_health and game.survived==3 and game.night==3,"completed run ignores late attacks and cannot award a fourth day"):return
	game.won=false;game.phase="night";game.night=4;game.night_elapsed=89.0;game.health=2
	game.take_damage(3);game.advance_phase(100)
	if not check(game.lost and game.phase=="lost" and game.survived==3 and game.health==0,"lethal real-time damage stops the clock without awarding survival"):return
	print("ALL_NIGHT_CYCLE_PASSED ",checks," checks")
	quit(0)
