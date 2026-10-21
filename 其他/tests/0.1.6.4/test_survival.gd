extends SceneTree
const Balance=preload("res://survival_balance.gd")
const Sanity=preload("res://sanity_system.gd")
var checks:=0
var failures:Array[String]=[]
var details:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func tick_sanity(game:Variant,seconds:float)->void:
	for i in range(roundi(seconds*20)):game.survival.update(game,.05)
func equip(game:Variant,id:String)->void:
	var index:int=game.bag.first(id)
	game.auto_equip(int(game.bag.slots[index].uid))
func key(game:Variant,k:int,down:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=k;e.keycode=k;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()
func run()->void:
	var game:Variant=load("res://main.tscn").instantiate();game.resource_seed=164
	root.add_child(game);game.set_process(false);await process_frame
	check(game.sanity==100 and game.health==100 and game.fullness==100,"initial survival values")
	check(game.day_duration==180 and game.dusk_duration==6 and game.night_duration==90,"unchanged cycle durations")
	game.wildlife.animals.clear();game.player=Vector2(1000,760)
	check(game.walkable(game.player),"real legal road movement origin")
	var start:Vector2=game.player;key(game,KEY_D,true)
	for i in range(20):game._process(.05)
	key(game,KEY_D,false)
	check(absf(game.player.distance_to(start)-108)<.1,"normal held-key movement108")
	game.wildlife.animals.clear();game.sanity=80;tick_sanity(game,60)
	check(is_equal_approx(game.sanity,80),"no passive daylight sanity loss")
	game.fullness=100;game.hunger_elapsed=0;game.advance_vitals(60)
	check(game.fullness==92 and game.hunger_elapsed<.0001,"exact eight hunger points per minute")
	game.fullness=1;game.hunger_elapsed=0;game.health=100;game.advance_vitals(10)
	check(game.fullness==0 and absf(game.health-98)<.01,"starvation damage only after hunger reaches zero")
	check(Balance.movement_scale(25)==1 and Balance.movement_scale(0)==.92,"mild low-food penalty, normal above25")
	game.fullness=100;game.phase="night";game.night_elapsed=30;game.sanity=100
	game.survival=Sanity.new();game.survival.setup(164);tick_sanity(game,60)
	check(absf(game.sanity-79)<.002,"night darkness loses21 sanity per minute")
	game.bag.add("torch",1);var tuid:int=int(game.bag.slots[game.bag.first("torch")].uid)
	game.torch_uid=tuid;game.torch_fuel=120;game.torch_lit=true
	var sanity_before:float=game.sanity;tick_sanity(game,30)
	check(game.sanity==sanity_before,"actual lit torch prevents darkness sanity drain")
	game.torch_lit=false;game.player=Vector2(360,760);game.sanity=50;game.moving=false;game.survival.rest_time=0;tick_sanity(game,23)
	check(game.survival.resting and absf(game.sanity-55.0125)<.04,"safe lit camp restores .25/sec after3s rest")
	game.fullness=100;game.hunger_elapsed=0;game.advance_vitals(60)
	check(game.fullness==92,"camp resting still consumes hunger")
	game.moving=true;game.survival.update(game,.05)
	check(not game.survival.resting,"movement cancels rest");game.moving=false
	game.sanity=98;game.survival.eat(game,4);check(game.sanity==100,"food recovery clamps max100")
	game.sanity=0;game.player=Vector2(1000,760);game.fullness=0;tick_sanity(game,1)
	check(game.sanity==0,"loss clamps min0")
	for value in [0,29.9,30,69.9,70,100]:
		check(Sanity.level(value)==("NORMAL" if value>=70 else ("UNSTABLE" if value>=30 else "CRITICAL")),"sanity boundary "+str(value))
	game.fullness=50;game.health=90;game.sanity=50;game.survival.illusion_in=1
	for mode in ["inventory","crafting","dialog","paused","browser_suspended"]:
		game.set(mode,"Rowan" if mode=="dialog" else true)
		var snap:Array=[game.elapsed,game.night_elapsed,game.sanity,game.fullness,game.health,game.survival.effect_time,game.survival.shadow_cooldown,game.torch_fuel,game.wildlife.animals.duplicate(true),game.npc_states.duplicate(true)]
		game._process(.05);game.advance_vitals(10);game.survival.update(game,10)
		check(snap==[game.elapsed,game.night_elapsed,game.sanity,game.fullness,game.health,game.survival.effect_time,game.survival.shadow_cooldown,game.torch_fuel,game.wildlife.animals,game.npc_states],mode+" freezes all survival and AI clocks")
		game.set(mode,"" if mode=="dialog" else false)
	# A shadow is a real reused wolf collider, cannot spawn above critical or in light.
	game.wildlife.animals.clear();game.player=Vector2(1250,760);game.sanity=30;game.survival.shadow_cooldown=0;game.survival.shadow_retry=0
	check(not game.wildlife.spawn_shadow(game),"shadow rejected at30")
	game.sanity=20;game.torch_lit=true;check(not game.wildlife.spawn_shadow(game),"shadow rejected in torchlight")
	game.torch_lit=false;game.phase="day";check(not game.wildlife.spawn_shadow(game),"shadow rejected during day")
	game.phase="night";game.survival.shadow_cooldown=0;game.survival.shadow_retry=0;game.survival.update(game,.05)
	check(game.wildlife.has_shadow(),"critical darkness spawns one shadow")
	var shadow:Dictionary={}
	for a in game.wildlife.animals:
		if a.get("shadow",false):shadow=a
	if not shadow.is_empty():
		check(shadow.p.distance_to(game.player)>=360 and game.wildlife._ground_clear(game,shadow,shadow.p),"shadow fair distance and real ground footprint")
		check(shadow.hp==42 and shadow.age==0,"shadow low health and initial warning grace")
	check(not game.wildlife.spawn_shadow(game),"at most one actual shadow")
	game.wildlife.dismiss_shadow();game.survival.update(game,.05)
	check(not game.wildlife.has_shadow() and game.survival.shadow_cooldown>49,"shadow respawn cooldown at least45sec")
	game.survival.shadow_cooldown=0;game.survival.shadow_retry=0;game.wildlife.spawn_shadow(game);game.sanity=36;game.survival.update(game,.05)
	check(not game.wildlife.has_shadow(),"shadow despawns above35")
	game.sanity=20;game.wildlife.spawn_shadow(game);game.torch_lit=true;game.survival.update(game,.05)
	check(not game.wildlife.has_shadow(),"shadow despawns on reaching effective light")
	game.torch_lit=false;game.sanity=40;game.fullness=50
	game.bag.add("fish",2);equip(game,"fish");var fish_before:int=game.bag.count("fish");game.use_selected()
	check(game.bag.count("fish")==fish_before-1 and game.fullness==75 and game.sanity==44,"fish consumes one real item for25food4sanity")
	game.fullness=100;game.use_selected();check(game.bag.count("fish")==fish_before-1 and game.sanity==44,"full-food spam cannot restore sanity")
	game.phase="day";game.interaction_cooldown=0;game.bag.add("branch",20);game.bag.add("rock",20);game.bag.add("rope",20)
	game.craft_recipe(0);check(game.selected_item().get("id","")=="stone_axe","normal field crafting and hotbar")
	check(game.bag.validate(),"inventory valid after consumption/crafting")
	# Actual tree approach and final contact, rather than forcing sprite overlap.
	var tree:Vector2=Vector2.ZERO
	for p in game.trees:
		for angle in range(16):
			var at:Vector2=p+Vector2.from_angle(angle*TAU/16)*54
			if game.walkable(at):
				game.player=at
				if game.target_line_clear(p):tree=p;break
		if tree!=Vector2.ZERO:break
	check(tree!=Vector2.ZERO,"legal real tree approach")
	game.tree_states[tree].hp=1;var log_before:int=game.bag.count("log")
	check(game.begin_action({"kind":"tree","pos":tree}),"axe harvesting starts")
	game.update_action(.55);game.update_action(.40)
	check(not game.tree_live(tree) and game.bag.count("log")==log_before+4,"actual action contact fells tree and awards materials")
	check(Balance.action_duration("iron_axe","tree",100)<Balance.action_duration("stone_axe","tree",100),"iron tool faster action")
	check(Balance.action_duration("amazing_sword","swing",100)<Balance.action_duration("stone_sword","swing",100),"advanced sword faster combat")
	# Reachable gathering and fishing opportunities on original ground polygons.
	var berries:=0;var near_food:=0;var food_paths:=0
	game.player=Vector2(360,760)
	for item in game.items:
		if item.kind!="berry":continue
		berries+=1
		if item.pos.distance_to(game.player)<540:near_food+=1
		var a:Vector2i=game.nav_cell(game.player);var b:Vector2i=game.nav_cell(item.pos+Vector2(0,30))
		if a.x>=0 and b.x>=0 and not game.nav_grid.get_id_path(a,b).is_empty():food_paths+=1
	check(berries>=9 and near_food>=3 and food_paths==berries,"sufficient reachable berry bushes, including starter region")
	details={"berries":berries,"near_food":near_food,"reachable_food":food_paths}
	var report:Dictionary={"checks":checks,"failures":failures,"details":details,"passed":failures.is_empty()}
	FileAccess.open(ProjectSettings.globalize_path("res://../survival-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("SURVIVAL_RESULTS ",JSON.stringify(report));game.queue_free();quit(0 if failures.is_empty() else 1)
