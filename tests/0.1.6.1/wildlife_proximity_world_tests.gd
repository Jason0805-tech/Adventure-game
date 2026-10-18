extends SceneTree
const Data=preload("res://wildlife_data.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures.append(label)
		if failures.size()<15:push_error("FAIL "+label)
func arena(game:Variant)->Vector2:
	for y in range(220,1280,40):
		for x in range(250,1950,40):
			var at:=Vector2(x,y)
			if at.distance_to(Data.CAMP)<430:continue
			var clear:=true
			for dy in range(-80,81,20):
				for dx in range(-80,201,20):
					if not game.static_walkable(at+Vector2(dx,dy)):clear=false
			if clear:return at
	return Vector2.ZERO
func one(game:Variant,species:String,p:Vector2,facing:Vector2)->Dictionary:
	game.wildlife.animals.clear();game.wildlife._spawn_one(game,species)
	var a:Dictionary=game.wildlife.animals[0]
	a.p=p;a.home=p;a.facing=facing;a.age=8.0;a.state="idle";a.timer=1.0
	game.wildlife.period="night" if Data.info(species).predator else "day"
	game.wildlife.respawn_in=999.0;game.wildlife.player_hit_grace=0.0
	return a
func step(game:Variant,a:Dictionary,period:String)->void:
	var previous:Vector2=a.p
	var previous_walk:float=a.walk
	game.wildlife.update(game,.05,period)
	var distance:float=a.p.distance_to(previous)
	check(game.wildlife._ground_clear(game,a,a.p),"actual encounter ground remains clear")
	check(a.p.distance_to(Data.CAMP)>=160,"actual encounter never enters camp")
	check(distance<8.0,"actual encounter never teleports")
	if distance<.01:
		check(not a.moving and is_zero_approx(float(a.gait_rate)) and is_equal_approx(float(a.walk),previous_walk),"blocked or planted feet never play a walk cycle")
	else:check(a.moving and float(a.gait_rate)>0.0,"only actual distance advances the walk")
func obstacle_encounter(game:Variant,species:String,separation:float=102.0)->Dictionary:
	var sim:Variant=game.wildlife
	for body in game.solid_bodies:
		if body.kind!="tree" or not game.body_active(body):continue
		var center:Vector2=body.bounds.get_center()
		if center.distance_to(Data.CAMP)<500:continue
		for side in [Vector2.RIGHT,Vector2.DOWN]:
			var from:Vector2=center-side*separation
			var target:Vector2=center+side*separation
			game.player=target
			var animal:Dictionary={"species":species,"uid":-99,"p":from,"facing":side}
			if not game.static_walkable(target) or not sim._walkable(game,animal,from):continue
			if sim._line_clear(game,from,target):continue
			if not sim._reachable(game,from,target):continue
			return {"from":from,"target":target,"body":body.id}
	return {}
func _run()->void:
	var game:Variant=load("res://main.tscn").instantiate();game.resource_seed=157
	root.add_child(game);game.set_process(false);await process_frame
	game.paused=false;game.inventory=false;game.crafting=false;game.dialog=""
	game.wildlife.animals.clear();game.bag=preload("res://inventory.gd").new()
	var open:Vector2=arena(game);check(open!=Vector2.ZERO,"real world offers an open proximity arena")
	for species in ["rabbit","fox"]:
		game.phase="day";game.player=open
		var a:Dictionary=one(game,species,open+Vector2(65,0),Vector2.RIGHT)
		var initial:float=a.p.distance_to(game.player);var health:float=game.health
		for tick in range(12):step(game,a,"day")
		check(a.state=="flee" and a.p.distance_to(game.player)>initial+25.0,"real world "+species+" flees and gains separation")
		check(game.health==health,"real world "+species+" causes no contact damage")
	for species in ["wolf","bear"]:
		game.phase="night";game.player=open;game.health=100.0
		var a:Dictionary=one(game,species,open+Vector2(130,0),Vector2.LEFT)
		var states:Dictionary={}
		for tick in range(160):
			step(game,a,"night");states[a.state]=true
			if a.state=="recover":break
		check(states.has("chase") and states.has("windup") and states.has("recover"),"real world "+species+" reaches chase, stopped warning and recovery")
		check(game.health==100.0-float(Data.info(species).damage),"real world "+species+" applies one actual bite/swipe")
		var health:float=game.health
		for tick in range(10):step(game,a,"night")
		check(game.health==health,"real world "+species+" recovery prevents repeated damage")
	# A real existing tree interrupts sight. This is a previously observed player,
	# not magical acquisition through a wall: the animal first visits last_seen.
	for species in ["wolf","bear"]:
		game.wildlife.animals.clear()
		var scene:Dictionary=obstacle_encounter(game,species)
		check(not scene.is_empty(),"real tree detour fixture exists for "+species)
		if scene.is_empty():continue
		game.phase="night";game.player=scene.target;game.health=100.0
		var a:Dictionary=one(game,species,scene.from,(scene.target-scene.from).normalized())
		a.state="chase";a.awareness=7.0;a.last_seen=scene.target;a.goal=scene.target
		var states:Dictionary={};var closest:float=a.p.distance_to(game.player)
		for tick in range(220):
			step(game,a,"night");states[a.state]=true
			closest=minf(closest,a.p.distance_to(game.player))
			if a.state=="recover":break
		check(states.has("investigate"),"real tree temporarily obscures "+species+" perception")
		check(states.has("windup") and states.has("recover"),"real "+species+" navigates around tree and resumes a fair attack")
		print("PROXIMITY_DETOUR species=",species," body=",scene.body," states=",states.keys()," closest=",closest," p=",a.p," player=",game.player)
	# Fresh, unobserved nearby predators can smell the player behind an actual
	# trunk. They investigate a route, while bite/swipe still requires clear sight.
	for species in ["wolf","bear"]:
		game.wildlife.animals.clear()
		var scene:Dictionary=obstacle_encounter(game,species,75.0)
		check(not scene.is_empty(),"nearby occluded scent fixture exists for "+species)
		if scene.is_empty():continue
		game.player=scene.target;game.health=100.0
		var a:Dictionary=one(game,species,scene.from,(scene.target-scene.from).normalized())
		check(not game.wildlife._line_clear(game,a.p,game.player),"scent starts without line of sight")
		step(game,a,"night")
		check(a.state=="investigate" and a.awareness>0.0,"nearby occluded "+species+" autonomously investigates player scent")
		var start:Vector2=a.p
		for tick in range(12):step(game,a,"night")
		check(a.p.distance_to(start)>8.0 and game.health==100.0,"scent investigation actually moves without attacking through trunk")
	print("NAVIGATION_CACHE_BUILD_USEC ",game.wildlife.navigation_build_usec," cache_hits=",game.wildlife.navigation_cache_hits)
	print("WILDLIFE_PROXIMITY_WORLD_RESULT checks=",checks," failures=",failures.size()," arena=",open)
	game.queue_free();quit(0 if failures.is_empty() else 1)
