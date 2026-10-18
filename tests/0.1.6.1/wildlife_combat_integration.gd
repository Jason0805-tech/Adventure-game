extends SceneTree
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]

func _initialize()->void:call_deferred("_run")

func check(condition:bool,label:String)->void:
	checks+=1
	if condition:print("PASS ",label)
	else:failures.append(label);push_error("FAIL "+label)

func open_arena(game:Variant)->Vector2:
	for y in range(220,1330,30):
		for x in range(180,2020,30):
			var p:=Vector2(x,y)
			if p.distance_to(Vector2(455,725))<340:continue
			var clear:=true
			for dy in range(-60,61,20):
				for dx in range(-60,121,20):
					if not game.static_walkable(p+Vector2(dx,dy)):clear=false
			if clear:return p
	return Vector2.ZERO

func encounter(game:Variant,species:String,at:Vector2)->Dictionary:
	game.wildlife.animals.clear()
	game.wildlife._spawn_one(game,species)
	var animal:Dictionary=game.wildlife.animals[0]
	animal.p=at;animal.home=at;animal.age=5.0;animal.state="idle";animal.timer=2.0
	animal.facing=Vector2.DOWN
	game.wildlife.period="night" if species in ["wolf","bear"] else "day"
	game.wildlife.respawn_in=28.0;game.wildlife.player_hit_grace=0.0
	return animal

func reset_action(game:Variant)->void:
	game.action.clear();game.interaction_cooldown=0.0

func equip(game:Variant,id:String)->int:
	if game.bag.first(id)<0:game.bag.add(id,1)
	var index:int=game.bag.first(id)
	var uid:int=int(game.bag.slots[index].uid)
	game.bind_hotbar(uid,0);game.active_hotbar=0
	return uid

func swing(game:Variant)->void:
	reset_action(game)
	game.use_selected()
	game.update_action(.50)

func _run()->void:
	var game:Variant=load("res://main.tscn").instantiate()
	game.resource_seed=157
	root.add_child(game);game.set_process(false)
	await process_frame
	game.phase="night";game.paused=false;game.inventory=false;game.crafting=false;game.dialog=""
	game.wildlife.animals.clear()
	var arena:Vector2=open_arena(game)
	check(arena!=Vector2.ZERO,"actual world contains a clear encounter arena")
	game.player=arena;game.facing=Vector2.RIGHT
	game.bag.add("branch",4);game.bag.add("rope",1)
	game.craft_recipe(2)
	check(game.selected_item().get("id","")=="wood_sword","crafting at night creates and equips an actual wooden sword")
	var sword_uid:int=int(game.selected_item().uid)
	var durability:int=int(game.bag.item_by_uid(sword_uid).durability)
	var wolf:Dictionary=encounter(game,"wolf",arena+Vector2(42,0))
	game.use_selected()
	check(not game.action.is_empty() and game.action.target.kind=="swing","use_selected starts actual night melee animation")
	game.update_action(.49)
	check(float(wolf.hp)==65,"windup before contact frame does not prematurely damage wolf")
	game.update_action(.02)
	check(float(wolf.hp)==35,"actual sword commit applies selected tool power damage")
	check(int(game.bag.item_by_uid(sword_uid).durability)==durability-1,"successful swing consumes exactly one durability")
	game.commit_action();game.update_action(.10)
	check(float(wolf.hp)==35 and int(game.bag.item_by_uid(sword_uid).durability)==durability-1,"committing the same action repeatedly cannot repeat hit or durability")
	wolf.hurt_grace=0.0;swing(game)
	check(float(wolf.hp)==5,"next actual action lands a separate sword hit")
	var original_power:int=int(game.power)
	wolf.hurt_grace=0.0;swing(game)
	check(game.wildlife.animals.is_empty() and int(game.power)==original_power+1,"actual final blow removes body and grants one experience")
	durability=int(game.bag.item_by_uid(sword_uid).durability)
	wolf=encounter(game,"wolf",arena+Vector2(100,0));swing(game)
	check(float(wolf.hp)==65 and int(game.bag.item_by_uid(sword_uid).durability)==durability,"out-of-reach swing misses without durability loss")
	wolf.p=arena+Vector2(-42,0);swing(game)
	check(float(wolf.hp)==65 and int(game.bag.item_by_uid(sword_uid).durability)==durability,"rear animal is outside actual weapon cone")
	wolf.p=arena+Vector2(42,0)
	var wall:=Rect2(arena+Vector2(20,-25),Vector2(5,50))
	var polygon:=PackedVector2Array([wall.position,wall.position+Vector2(wall.size.x,0),wall.end,wall.position+Vector2(0,wall.size.y)])
	game.solid_bodies.append({"kind":"prop","polygon":polygon,"bounds":wall})
	swing(game)
	check(float(wolf.hp)==65 and int(game.bag.item_by_uid(sword_uid).durability)==durability,"actual commit cannot hit through intervening ground solid")
	game.solid_bodies.pop_back()
	# Tool prioritization is checked at a real, legal tree approach.
	var tree_pos:=Vector2.ZERO
	for p in game.trees:
		var candidate:Vector2=p+Vector2(0,52)
		if candidate.distance_to(Vector2(455,725))<220:continue
		game.player=candidate
		if game.static_walkable(candidate) and game.static_walkable(candidate+Vector2(42,0)) and game.target_line_clear(p):
			tree_pos=p;game.player=candidate;break
	check(tree_pos!=Vector2.ZERO,"actual tree has a legal adjacent tool/combat encounter")
	game.facing=Vector2.RIGHT
	var axe_uid:int=equip(game,"stone_axe")
	wolf=encounter(game,"wolf",game.player+Vector2(42,0))
	var tree_hp:int=int(game.tree_states[tree_pos].hp)
	reset_action(game);game.use_selected()
	check(game.action.target.kind=="swing","axe prioritizes facing nearby animal over adjacent tree")
	game.update_action(.51)
	check(float(wolf.hp)==35 and int(game.tree_states[tree_pos].hp)==tree_hp,"axe hits wolf without silently chopping nearby tree")
	# Player and NPC motion share the same dynamic ground contacts.
	game.player=arena;game.facing=Vector2.RIGHT
	wolf=encounter(game,"wolf",arena+Vector2(42,0))
	check(not game.walkable(wolf.p),"player cannot move through animal feet")
	check(not game.npc_walkable(wolf.p,"Ash"),"NPC cannot move through animal feet")
	var bench_p:Vector2=arena+Vector2(100,0)
	game.wildlife.animals.clear()
	check(game.can_place_bench(bench_p),"actual clear ground accepts bench before animal arrives")
	encounter(game,"rabbit",bench_p)
	check(not game.can_place_bench(bench_p),"actual bench placement rejects animal ground overlap")
	# Passive wildlife flees instead of applying contact damage.
	game.phase="day";game.player=arena;game.health=100
	var rabbit:Dictionary=encounter(game,"rabbit",arena+Vector2(48,0))
	var start_distance:float=rabbit.p.distance_to(game.player)
	for index in range(8):game.wildlife.update(game,.05,"day")
	check(rabbit.state=="flee" and rabbit.p.distance_to(game.player)>start_distance and game.health==100,"actual day rabbit flees with no contact damage")
	# Real host callback: windup then damage, player blow interrupts it.
	game.phase="night";game.player=arena;game.health=100;game.facing=Vector2.RIGHT
	equip(game,"wood_sword")
	wolf=encounter(game,"wolf",arena+Vector2(42,0))
	game.wildlife.update(game,.05,"night")
	check(wolf.state=="windup" and game.health==100,"real predator emits stopped warning before host damage")
	swing(game)
	check(wolf.state=="recover","actual player action interrupts predator warning")
	for index in range(10):game.wildlife.update(game,.05,"night")
	check(game.health==100,"interrupted warning cannot finish as an invisible bite")
	wolf=encounter(game,"wolf",arena+Vector2(42,0));game.health=100
	for index in range(16):game.wildlife.update(game,.05,"night")
	check(game.health==88,"unopposed real wolf bite applies host health damage exactly once")
	var health_after:float=float(game.health)
	for index in range(12):game.wildlife.update(game,.05,"night")
	check(game.health==health_after,"real predator recovery prevents repeated contact damage")
	game.bag.add("crystal",2);game.health=100
	var ward_count:int=game.bag.count("crystal")
	var dealt:float=game.wildlife_damage(22,"bear")
	check(dealt==0 and game.health==100 and game.bag.count("crystal")==ward_count-1,"one magic stone absorbs exactly one actual animal hit")
	for mode in ["paused","inventory","crafting","dialog"]:
		if mode=="dialog":game.dialog="Test conversation"
		else:game.set(mode,true)
		ward_count=game.bag.count("crystal")
		dealt=game.wildlife_damage(22,"bear")
		check(dealt==0 and game.health==100 and game.bag.count("crystal")==ward_count,"modal "+mode+" prevents damage and ward consumption")
		if mode=="dialog":game.dialog=""
		else:game.set(mode,false)
	print("WILDLIFE_COMBAT_INTEGRATION checks=",checks," failures=",failures.size()," arena=",arena)
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
