extends "res://../../tests/0.1.5.11/test_front_contact_visibility.gd"
const Geometry=preload("res://world_geometry.gd")
var full_world:Array[Dictionary]=[]
var profile_counts:Dictionary={}
var actual_instances:=0
var variants:=0
var tested_states:Dictionary={}
var poses:Array=[]
func own_bodies(entry:Dictionary)->Array[Dictionary]:
	var own:Array[Dictionary]=[]
	for body in full_world:
		if str(body.id)==str(entry.id) and game.body_active(body):own.append(body)
	return own
func find_texture_keys(entry:Dictionary,spec:Dictionary)->Array:
	var keys:Array=[]
	if game.has_method("paint_entries"):
		for paint in game.paint_entries():
			if str(paint.id).begins_with(str(entry.id)+":band:") and not keys.has(paint.texture.get_instance_id()):keys.append(str(paint.texture.get_instance_id()))
	if keys.is_empty() and not spec.is_empty():
		var rect:Rect2=game.sprite_rect(spec.texture,spec.foot,float(spec.height))
		keys.append(str(game.paint_density.prepare_rect(spec.texture,rect.size).get_instance_id()))
	return keys
func test_entry(entry:Dictionary,state:String,all_columns:bool)->void:
	var own:Array[Dictionary]=own_bodies(entry)
	if own.is_empty():return
	var spec:Dictionary=game.model_spec(str(entry.kind),entry.p,int(entry.index))
	var profile:String=str(entry.get("profile",spec.get("profile",entry.kind)))
	var key:String=profile+":"+state
	var bounds:Rect2=own[0].bounds
	for body in own:bounds=bounds.merge(body.bounds)
	game.solid_bodies=own
	only_texture_keys=find_texture_keys(entry,spec)
	only_world_origins=[spec.foot] if not spec.is_empty() else [Vector2.ZERO]
	var columns:Array=[0.2,0.5,0.8] if all_columns else [0.5]
	for fraction in columns:
		game.player=Vector2(lerpf(bounds.position.x,bounds.end.x,fraction),bounds.end.y+35)
		game.facing=Vector2.UP
		if not game.walkable(game.player):continue
		game.move_player(Vector2.UP,(bounds.size.y+65)/game.SPEED)
		if game.walkable(game.player+Vector2(0,-3)):continue # This column is genuinely open.
		# Trees retain canopy/root depth; a branch contact above the root is a
		# legitimate behind-canopy pose and is covered by fade tests elsewhere.
		if entry.kind=="tree" and state=="live" and game.player.y<game.model_depth(spec):continue
		var label:String="%s-%s-%s-col%d"%[profile,state,str(entry.p).replace(" ",""),int(fraction*100)]
		var previous_failures:int=failures
		measure(label,false)
		profile_counts[key]=int(profile_counts.get(key,0))+1
		var pose:Dictionary={"entry":{"kind":entry.kind,"p":[entry.p.x,entry.p.y],"index":int(entry.index),"id":entry.id},"profile":profile,"state":state,"player":[game.player.x,game.player.y],"facing":[0,-1],"label":label,"pass":failures==previous_failures}
		poses.append(pose)
		# Always save one real rendered contact for every exported model/state;
		# failures also save their actual paint commands for diagnosis.
		if not tested_states.has(key) or failures>previous_failures:
			save_world_capture("allfront-"+label)
			tested_states[key]=true
	game.solid_bodies=full_world
func passable_fronts(state:String)->void:
	for entry in game.scenery_entries():
		if entry.kind!="resource" or not own_bodies(entry).is_empty():continue
		var spec:Dictionary=game.model_spec("resource",entry.p,int(entry.index))
		var state_key:String=str(spec.profile)+":"+state
		if tested_states.has(state_key):continue
		game.player=Vector2(entry.p.x,entry.p.y+10);game.facing=Vector2.UP
		only_texture_keys=find_texture_keys(entry,spec);only_world_origins=[spec.foot]
		measure(str(spec.profile)+"-passable-"+state,false)
		tested_states[state_key]=true
		save_world_capture("allfront-"+str(spec.profile)+"-passable-"+state)
func scene_entries()->Array[Dictionary]:
	var entries:Array[Dictionary]=[]
	for entry in game.scenery_entries():
		if entry.kind not in ["player","Rowan","Ash"]:entries.append(entry)
	for body in full_world:
		if body.kind=="bank_rock":entries.append({"kind":body.kind,"p":body.p,"index":body.index,"id":body.id,"profile":body.profile})
	return entries
func run()->void:
	game=load(OUT+"snapshot_game.gd").new();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(50,1450);game.npc_position=Vector2(90,1450);game.message_time=0;game.show_collision=false;game.day_time=30
	full_world=game.solid_bodies.duplicate(true)
	for entry in scene_entries():
		test_entry(entry,"live",not tested_states.has(str(game.model_spec(str(entry.kind),entry.p,int(entry.index)).get("profile",entry.kind))+":live"))
		actual_instances+=1
	passable_fronts("live")
	print("ALL_FRONT_ACTUAL_DONE checks=",checks," failures=",failures)
	for p in game.trees:game.tree_states[p].felled=true
	for item in game.items:item.taken=true
	for vein in game.ore_veins:vein.depleted=true
	game.rebuild_obstacles();full_world=game.solid_bodies.duplicate(true)
	for entry in scene_entries():
		if entry.kind in ["tree","ore"]:test_entry(entry,"depleted",true);variants+=1
	passable_fronts("spent")
	# Alternate camp variants not present in the actual world.
	for sprite in [1,2,3,4,5]:
		var index:int=game.props.size();game.props.append({"p":Vector2(1100,1350),"sprite":sprite,"height":49.0})
		game.rebuild_obstacles();full_world=game.solid_bodies.duplicate(true)
		test_entry(game.scenery_entry("prop",game.props[index].p,index),"alternate",true);variants+=1
	game.player=Vector2(1620,760);game.facing=Vector2.RIGHT
	game.bag.add("workbench",1);game.hotbar[0]=int(game.bag.slots[0].uid);game.active_hotbar=0
	var placed:bool=game.place_workbench()
	assert(placed,"Workbench placement on clear road")
	full_world=game.solid_bodies.duplicate(true)
	test_entry(game.scenery_entry("bench",game.workbenches[-1].p,game.workbenches.size()-1),"placed",true)
	var summary:Dictionary={"version":"0.1.5.11","checks":checks,"failures":failures,"actual_instances":actual_instances,"alternate_state_instances":variants,"per_profile_front_contacts":profile_counts,"results":results,"method":"Every actual static solid instance approached from below with real player movement; every model/state has additional front columns. Actual ordered Canvas calls are alpha-composited against original opaque avatar pixels. Only that object's actual prepared source textures contribute to the visibility failure, so unrelated neighboring canopies cannot hide a regression. Full-world collision routes are tested separately. Tree contacts above the root are legitimately behind canopy and excluded from front-only acceptance."}
	var file:=FileAccess.open(OUT+"all-model-front-visibility.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	file=FileAccess.open(OUT+"all-model-front-poses.json",FileAccess.WRITE);file.store_string(JSON.stringify({"poses":poses},"\t"));file.close()
	print("ALL_MODEL_FRONT_VISIBILITY checks=",checks," failures=",failures," actual_instances=",actual_instances," alternate_states=",variants)
	game.queue_free();quit(0 if failures==0 else 1)
