extends SceneTree
const Geometry=preload("res://world_geometry.gd")
const OUT="res://../../tests/0.1.5.11/"
var game:Variant
var checks:=0
var failures:=0
var labels:Array=[]
var covered_profiles:Dictionary={}
var positive_samples:=0
var negative_samples:=0
var motion_cases:=0
var mapped_stones:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if labels.size()<200:labels.append(label);push_error("GROUND_SEMANTIC_FAIL "+label)
func add_fixtures()->void:
	# Use the normal arrays/model_spec/rebuild pipeline. Fixtures overlap only
	# in this test; each sample is tested against its own object in isolation.
	for i in range(6):
		for parity in range(2):
			var p:=Vector2(1100+i*4+parity,1100)
			game.trees.append(p);game.tree_styles[p]=i;game.tree_states[p]={"hp":3,"felled":false,"shake":0.0}
	for i in range(4):game.shrubs.append(Vector2(1200+i,1100))
	for i in range(6):game.props.append({"p":Vector2(1300+i,1100),"sprite":i,"height":222.0 if i==0 else 55.0})
	for row in range(3):
		for spent in [false,true]:
			for variant in range(3):
				game.items.append({"pos":Vector2(1450+row*20+variant,1100),"kind":["branch","rock","rope"][row],"taken":spent,"variant":variant,"mirror":false})
	for i in range(3):
		for depleted in [false,true]:game.ore_veins.append({"p":Vector2(1600+i,1100+(10 if depleted else 0)),"hp":0 if depleted else 3,"depleted":depleted,"variant":i})
	for i in range(2):
		var p:=Vector2(1650+i,1100);game.trees.append(p);game.tree_states[p]={"hp":0,"felled":true,"shake":0.0}
	game.rebuild_obstacles()
func own(entry:Dictionary,all_bodies:Array[Dictionary])->Array[Dictionary]:
	var bodies:Array[Dictionary]=[]
	for body in all_bodies:
		if str(body.id)==str(entry.id):bodies.append(body)
	return bodies
func inside(point:Vector2,bodies:Array[Dictionary])->bool:
	for body in bodies:
		if Geometry.point_in_polygon_or_boundary(point,body.polygon):return true
	return false
func translate(bodies:Array[Dictionary],shift:Vector2)->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for source in bodies:
		var body:Dictionary=source.duplicate(true)
		body.polygon=Geometry.transform_polygon(body.polygon,shift);body.bounds=Geometry.polygon_bounds(body.polygon);body.p+=shift
		result.append(body)
	return result
func exercise(sample:Dictionary,point:Vector2,bodies:Array[Dictionary],label:String,width:float)->void:
	var center:=Vector2(1100,750)
	game.solid_bodies=translate(bodies,center-point)
	var covered:bool=inside(center,game.solid_bodies)
	if sample.expect=="solid":
		positive_samples+=1
		check(covered,label+" source-ground center inside own footprint")
		check(not game.static_walkable(center),label+" boots rejected on own ground solid")
		var reach:=180.0
		for body in game.solid_bodies:reach=maxf(reach,body.bounds.size.length()+80.0)
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			game.player=center-direction*reach
			check(game.walkable(game.player),label+" cardinal start clear "+str(direction))
			game.move_player(direction,2.0*reach/game.SPEED)
			check(game.walkable(game.player),label+" long-frame boots remain legal "+str(direction))
			check((game.player-center).dot(direction)<0,label+" own ground volume blocks crossing "+str(direction))
			motion_cases+=1
	else:
		negative_samples+=1
		check(not covered,label+" source upper/soft center not a physical wall")
		if bool(sample.capsule_clear):
			check(game.static_walkable(center),label+" entire actor boot capsule clear below overhead/soft sprite")
			var reach:=maxf(80.0,width+40.0)
			game.player=center-Vector2(reach,0)
			game.move_player(Vector2.RIGHT,reach*2.0/game.SPEED)
			check(game.player.distance_to(center+Vector2(reach,0))<0.1,label+" real horizontal overhead route unobstructed")
			motion_cases+=1
func run()->void:
	var doc:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"independent-ground-landmarks.json"))
	game=load("res://main.tscn").instantiate();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(70,60);game.npc_position=Vector2(110,60)
	add_fixtures()
	var all_bodies:Array[Dictionary]=game.solid_bodies.duplicate(true)
	var specimens:Dictionary={}
	for entry in game.scenery_entries():
		if entry.kind in ["Rowan","Ash","player"]:continue
		var spec:Dictionary=game.model_spec(entry.kind,entry.p,int(entry.index))
		if spec.is_empty():continue
		if not specimens.has(spec.profile):specimens[spec.profile]=[]
		specimens[spec.profile].append({"entry":entry,"spec":spec})
	for sample in doc.samples:
		var profile:String=sample.profile;covered_profiles[profile]=true
		if profile.begins_with("pond_"):
			var pond_index:int=int(profile.split("_")[1]);var rect:Rect2=game.pools[pond_index]
			var point:Vector2=rect.position+Vector2(sample.uv[0],sample.uv[1])*rect.size
			var bodies:Array[Dictionary]=[]
			for body in all_bodies:
				if str(body.profile)==profile:bodies.append(body)
			if profile.ends_with("_rocks"):
				var selected:Array[Dictionary]=[]
				for body in bodies:
					if Geometry.point_in_polygon_or_boundary(point,body.polygon):selected.append(body);mapped_stones[body.id]=true
				# Missing stone remains a failure, rather than being hidden by water.
				bodies=selected
			exercise(sample,point,bodies,profile+":"+sample.part,rect.size.x)
			continue
		check(specimens.has(profile),profile+" has a normal runtime specimen")
		if not specimens.has(profile):continue
		# Exercise all actual variants/mirrors, never substitute neighbors.
		for specimen in specimens[profile]:
			var spec:Dictionary=specimen.spec;var entry:Dictionary=specimen.entry
			var rect:Rect2=game.sprite_rect(spec.texture,spec.foot,float(spec.height))
			var point:Vector2=rect.position+Vector2(sample.uv[0],sample.uv[1])*rect.size
			if bool(spec.mirror):point.x=spec.foot.x*2.0-point.x
			exercise(sample,point,own(entry,all_bodies),profile+":"+sample.part+":"+str(entry.id),rect.size.x)
	check(covered_profiles.size()==48,"all 48 profile classes/variants covered independently")
	check(mapped_stones.size()==17,"all 17 shore stones each have their own ground body, separate from water")
	game.solid_bodies=all_bodies
	var summary:Dictionary={"version":"0.1.5.11","checks":checks,"failures":failures,"source_landmarks":doc.samples.size(),"profile_count":covered_profiles.size(),"positive_instance_samples":positive_samples,"negative_instance_samples":negative_samples,"distinct_own_shore_stones":mapped_stones.size(),"real_movement_cases":motion_cases,"failure_labels":labels,"method":doc.method}
	var file:=FileAccess.open(OUT+"independent-ground-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("INDEPENDENT_GROUND_RESULTS ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
