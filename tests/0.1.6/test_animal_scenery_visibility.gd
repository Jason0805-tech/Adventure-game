extends SceneTree
## Named-model alpha inspection of the release's actual Canvas commands.
## Physics locates contacts; expected ordering is never derived from depth metadata.
const OUT:="res://../../tests/0.1.6/"
const Geometry=preload("res://world_geometry.gd")
var game:Variant
var images:Dictionary={}
var full_world:Array[Dictionary]=[]
var results:Array=[]
var failures:Array=[]
var contacts:Array=[]
var unavailable:Array=[]
var samples_checked:=0
func _initialize()->void:call_deferred("run")
func pixels(path:String)->Image:
	if not images.has(path):images[path]=Image.load_from_file(path)
	return images[path]
func alpha_at(command:Dictionary,screen:Vector2)->float:
	var transform:Array=command.transform
	var scale:=Vector2(float(transform[3]),float(transform[4]))
	if scale.x==0 or scale.y==0:return 0.0
	var p:Vector2=(screen-Vector2(transform[0],transform[1])).rotated(-float(transform[2]))/scale
	var r:Array=command.rect
	var rect:=Rect2(r[0],r[1],r[2],r[3])
	if not rect.has_point(p):return 0.0
	var image:Image=pixels(command.texture.path)
	var source:=Rect2(Vector2.ZERO,Vector2(image.get_width(),image.get_height()))
	if command.has("source"):
		var raw:Array=command.source;source=Rect2(raw[0],raw[1],raw[2],raw[3])
	var q:Vector2=source.position+(p-rect.position)/rect.size*source.size
	return image.get_pixel(clampi(int(q.x),0,image.get_width()-1),clampi(int(q.y),0,image.get_height()-1)).a*float(command.color[3])
func animal_at(species:String,p:Vector2,facing:Vector2)->Dictionary:
	return {"uid":1,"species":species,"p":p,"home":p,"facing":facing,"hp":float(game.wildlife.Data.info(species).health),"moving":true,"walk":0.0,"age":10.0,"hitflash":0.0,"hurt_grace":0.0,"state":"chase","timer":5.0,"goal":p,"path":PackedVector2Array(),"cursor":0,"repath":999.0,"stuck":0.0,"locked_aim":p,"nav_revision":game.nav_revision}
func own_bodies(entry:Dictionary)->Array[Dictionary]:
	var own:Array[Dictionary]=[]
	for body in full_world:
		if str(body.id)==str(entry.id) and game.body_active(body):own.append(body)
	return own
func entries(kind:String)->Array[Dictionary]:
	var output:Array[Dictionary]=[]
	if kind=="bank_rock":
		for body in full_world:
			if body.kind==kind:output.append({"kind":kind,"p":body.p,"index":body.index,"id":body.id})
	else:
		for entry in game.scenery_entries():
			if entry.kind==kind:
				if kind=="tree" and (entry.p.x<170 or entry.p.x>2030 or entry.p.y<230 or entry.p.y>1320):continue
				if entry.p.distance_to(game.CAMP)<240:continue
				output.append(entry)
	return output
func bounds_of(own:Array[Dictionary])->Rect2:
	var bounds:Rect2=own[0].bounds
	for body in own:bounds=bounds.merge(body.bounds)
	return bounds
func move_contact(animal:Dictionary,entry:Dictionary,direction:Vector2,fraction:float,isolated:bool)->Dictionary:
	var own:Array[Dictionary]=own_bodies(entry)
	if own.is_empty():return {}
	var bounds:Rect2=bounds_of(own)
	game.solid_bodies=own if isolated else full_world
	var p:=Vector2(lerpf(bounds.position.x,bounds.end.x,fraction),bounds.end.y+70 if direction.y<0 else bounds.position.y-70)
	animal.p=p;animal.home=p;animal.facing=direction;animal.walk=0.0;animal.stuck=0.0
	animal.cursor=0;animal.repath=999.0;animal.nav_revision=game.nav_revision
	animal.goal=p+direction*(bounds.size.y+150)
	animal.path=PackedVector2Array([animal.goal])
	game.wildlife.animals.assign([animal])
	if not game.wildlife._walkable(game,animal,p):return {}
	var travelled:=0.0
	for step in range(140):
		var old:Vector2=animal.p
		game.wildlife._move_toward(game,animal,animal.goal,60.0,0.05)
		travelled+=animal.p.distance_to(old)
		if animal.p.distance_to(old)<0.001:break
	var stopped:bool=not game.wildlife._walkable(game,animal,animal.p+direction*3)
	var own_hit:=false
	var forward:PackedVector2Array=game.wildlife.footprint(animal,animal.p+direction*3)
	for body in own:
		if Geometry.polygons_overlap(forward,body.polygon):own_hit=true
	var legal:bool=game.wildlife._walkable(game,animal,animal.p)
	return {"p":animal.p,"facing":animal.facing,"travelled":travelled,"target_contact":stopped and own_hit and legal and travelled>1.0,"start":p,"legal":legal}
func target_textures(entry:Dictionary)->Dictionary:
	var keys:Dictionary={}
	for paint in game.paint_entries():
		if str(paint.id).begins_with(str(entry.id)+":") and paint.has("texture"):keys[str(paint.texture.get_instance_id())]=true
	var spec:Dictionary=game.model_spec(str(entry.kind),entry.p,int(entry.index))
	if not spec.is_empty():
		var r:Rect2=game.sprite_rect(spec.texture,spec.foot,float(spec.height))
		keys[str(game.paint_density.prepare_rect(spec.texture,r.size).get_instance_id())]=true
	return keys
func save_world(name:String)->void:
	var original:Array=game.commands
	var world:Array=[]
	for command in original:
		var t:Array=command.transform
		if absf(float(t[0]))<0.0001 and absf(float(t[1]))<0.0001:break
		world.append(command)
	game.commands=world;game.save_capture(name,440,340);game.commands=original
func measure(entry:Dictionary,animal:Dictionary,mode:String,frame:int,context:Dictionary)->void:
	animal.moving=true
	animal.walk=float(game.wildlife.Data.info(animal.species).stride)*float(frame)/4.0
	game.camera=animal.p-Vector2(220,230)
	var keys:Dictionary=target_textures(entry)
	game.reset_capture();game._draw()
	var animal_key:=str(game.animal_atlases[animal.species].get_instance_id())
	var actor:Dictionary={}
	var own:Array=[]
	var after:Array=[]
	var seen:=false
	for command in game.commands:
		if command.kind!="texture":continue
		var filename:=str(command.texture.path)
		if filename.ends_with("-"+animal_key+".png"):
			actor=command;seen=true;continue
		var eligible:=false
		for key in keys:
			if filename.ends_with("-"+str(key)+".png"):eligible=true;break
		if not eligible:continue
		if entry.kind!="bank_rock":
			var spec:Dictionary=game.model_spec(str(entry.kind),entry.p,int(entry.index))
			var origin:Vector2=Vector2(command.transform[0],command.transform[1])+game.camera
			if origin.distance_to(spec.foot)>0.1:continue
		own.append(command)
		if seen:after.append(command)
	var label:String="%s-%s-%s-frame%d"%[animal.species,entry.kind,mode,frame]
	if actor.is_empty():failures.append(label+" missing animal paint");return
	var image:Image=pixels(actor.texture.path)
	var source:Array=actor.source
	var rect:Array=actor.rect
	var transform:Array=actor.transform
	var samples:=0
	var overlap:=0
	var covered:=0
	var sum_survival:=0.0
	var overlap_survival:=0.0
	var minimum:=1.0
	var hidden:Array=[]
	# All body parts, including paws/tail/antlers; sample the genuine384px
	# source cell, not the human avatar's former96x160 crop.
	for y in range(3,int(source[3]),6):
		for x in range(3,int(source[2]),6):
			if image.get_pixel(int(source[0])+x,int(source[1])+y).a<0.92:continue
			var local:=Vector2(float(rect[0])+x/float(source[2])*float(rect[2]),float(rect[1])+y/float(source[3])*float(rect[3]))
			var point:Vector2=Vector2(transform[0],transform[1])+ (local*Vector2(transform[3],transform[4])).rotated(float(transform[2]))
			var model_alpha:=0.0
			for command in own:model_alpha=1.0-(1.0-model_alpha)*(1.0-alpha_at(command,point))
			var survival:=1.0
			for command in after:survival*=1.0-alpha_at(command,point)
			samples+=1;sum_survival+=survival;minimum=minf(minimum,survival)
			if model_alpha>0.05:overlap+=1;overlap_survival+=survival
			if survival<0.75:
				covered+=1
				if hidden.size()<15:hidden.append({"source_local":[x,y],"screen":[point.x,point.y],"survival":survival})
	var mean:float=sum_survival/maxi(1,samples)
	var overlap_mean:float=overlap_survival/maxi(1,overlap)
	var passed:bool=samples>=10 and not own.is_empty()
	if mode=="front":passed=passed and mean>=0.985 and covered==0
	else:passed=passed and (overlap<3 or covered>0)
	if not passed:failures.append(label)
	samples_checked+=samples
	var row:Dictionary={"label":label,"species":animal.species,"entry_id":entry.id,"mode":mode,"frame":frame,"p":[animal.p.x,animal.p.y],"facing":[animal.facing.x,animal.facing.y],"opaque_source_samples":samples,"model_overlap_samples":overlap,"covered_samples":covered,"mean_surviving_opacity":mean,"overlap_mean_surviving_opacity":overlap_mean,"minimum_survival":minimum,"target_paint_commands":own.size(),"pass":passed,"hidden_examples":hidden,"contact":context}
	results.append(row)
	if frame==0 or not passed:save_world("animal-depth-"+label)
	print("ANIMAL_ALPHA ",label," overlap=",overlap," covered=",covered," mean=",mean," pass=",passed)
func run()->void:
	game=load(OUT+"snapshot_game.gd").new();game.resource_seed=161
	root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.wildlife.animals.clear()
	game.player=Vector2(2100,1400);game.npc_home=Vector2(45,1450);game.npc_position=Vector2(85,1450)
	for npc in game.npc_states.values():npc.p=Vector2(45,1450)
	game.phase="day";game.day_time=55;game.elapsed=0;game.message_time=0
	full_world=game.solid_bodies.duplicate(true)
	for species in ["rabbit","deer","fox","wolf","bear"]:
		for kind in ["tree","ore","bank_rock"]:
			var chosen:Dictionary={}
			var front:Dictionary={};var back:Dictionary={}
			var animal:Dictionary=animal_at(species,Vector2(1200,1000),Vector2.UP)
			var fraction:=0.5
			var best_score:=-1
			for entry in entries(kind):
				for u in [0.5,0.3,0.7]:
					front=move_contact(animal,entry,Vector2.UP,float(u),true)
					back=move_contact(animal,entry,Vector2.DOWN,float(u),true)
					if front.is_empty() or back.is_empty() or not front.target_contact or not back.target_contact:continue
					# Prefer genuinely accessible land-side contacts using geometry
					# alone. Visibility is not consulted during target selection.
					game.solid_bodies.assign(full_world)
					animal.p=front.p;animal.facing=front.facing
					var front_legal:bool=game.wildlife._walkable(game,animal,animal.p)
					animal.p=back.p;animal.facing=back.facing
					var back_legal:bool=game.wildlife._walkable(game,animal,animal.p)
					var front_route:Dictionary=move_contact(animal,entry,Vector2.UP,float(u),false)
					var back_route:Dictionary=move_contact(animal,entry,Vector2.DOWN,float(u),false)
					var score:int=(200 if front_legal and not front_route.is_empty() and front_route.target_contact else 0)+(100 if back_legal and not back_route.is_empty() and back_route.target_contact else 0)+(20 if front_legal else 0)+(10 if back_legal else 0)
					if score>best_score:chosen=entry;fraction=float(u);best_score=score
					if score==330:break
				if best_score==330:break
			if chosen.is_empty():failures.append(species+" "+kind+" no own-ground contact pair");continue
			for mode in ["front","back"]:
				var direction:Vector2=Vector2.UP if mode=="front" else Vector2.DOWN
				var pose:Dictionary=move_contact(animal,chosen,direction,fraction,true)
				var isolated_position:Vector2=animal.p
				var isolated_facing:Vector2=animal.facing
				game.solid_bodies.assign(full_world)
				var full_world_legal:bool=game.wildlife._walkable(game,animal,animal.p)
				var real_route:Dictionary=move_contact(animal,chosen,direction,fraction,false)
				var reaches:bool=not real_route.is_empty() and bool(real_route.target_contact)
				var context:Dictionary={"own_ground_legal":bool(pose.legal),"full_world_legal":full_world_legal,"full_world_route_reaches_target":reaches,"approach_distance":float(pose.travelled),"approach_start":[pose.start.x,pose.start.y],"method":"actual wildlife._move_toward with ground capsules; own-body isolation; full-world repeat reported separately"}
				contacts.append(context.merged({"species":species,"kind":kind,"mode":mode,"entry_id":chosen.id}))
				if not reaches:unavailable.append({"species":species,"kind":kind,"mode":mode,"reason":"full-world approach unavailable (other scenery/water or crowded start); not counted as a full-world visit"})
				animal.p=isolated_position;animal.facing=isolated_facing
				game.solid_bodies.assign(full_world)
				for frame in range(4):measure(chosen,animal,mode,frame,context)
	var report:Dictionary={"version":"0.1.6","checks":results.size(),"failures":failures,"opaque_source_samples":samples_checked,"contacts":contacts,"unavailable_full_world_routes":unavailable,"results":results,"method":"Actual ordered release Canvas commands, five native species atlases and four frames per front/back contact. Only the named tree/ore/shore-stone paint texture and transformed origin are allowed to occlude. Contacts use real wildlife movement and heading-dependent ground capsules. Full-world legality and actual repeated approach are reported separately from isolated contacts. Conditional back acceptance requires source-over occlusion wherever opaque source paint actually overlaps. Software Canvas inspection, not native GPU screenshots or manual playthrough."}
	var file:=FileAccess.open(OUT+"animal-scenery-visibility.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("ANIMAL_SCENERY_VISIBILITY checks=",results.size()," samples=",samples_checked," failures=",failures.size()," contacts=",contacts.size()," fullworld_unavailable=",unavailable.size())
	for failure in failures:print("ANIMAL_VISIBILITY_FAILURE ",failure)
	game.queue_free();quit(0 if failures.is_empty() else 1)
