extends RefCounted
## Random destinations are decisions, not random per-frame directions.
## Human feet advance the approved complete eight-frame rig by distance walked.
const Geometry=preload("res://world_geometry.gd")
const CAMP=Vector2(455,725)
const WALK_STRIDE=60.48
var rng:=RandomNumberGenerator.new()

func setup(_game:Variant,seed_value:int=0) -> void:
	if seed_value==0:rng.randomize()
	else:rng.seed=seed_value^0x16C0A1

func _initialize_actor(name:String,npc:Dictionary) -> void:
	if npc.has("roaming_initialized"):return
	npc.roaming_initialized=true
	npc.home=npc.p
	npc.goal=npc.p
	npc.previous_goal=npc.p
	npc.path=PackedVector2Array()
	npc.cursor=0
	npc.replan=0.0
	npc.wait=rng.randf_range(0.4,2.6)
	npc.look_in=rng.randf_range(0.7,2.4)
	npc.stuck=0.0
	npc.nav_revision=-1
	npc.schedule="day"
	npc.activity="rest"
	npc.goals_chosen=0
	npc.pace=rng.randf_range(0.93,1.08)
	npc.roam_radius=175.0 if name=="Rowan" else 355.0
	npc.leg=Vector2(58,160) if name=="Rowan" else Vector2(110,295)
	npc.refuge=CAMP+Vector2(30,54) if name=="Rowan" else CAMP+Vector2(63,74)

func update(game:Variant,dt:float) -> void:
	if dt<=0.0 or game.paused or game.phase not in ["day","dusk","night"]:return
	if game.inventory or game.crafting or not game.dialog.is_empty():return
	for name in game.npc_states:
		var npc:Dictionary=game.npc_states[name]
		_initialize_actor(str(name),npc)
		npc.moving=false
		npc.wait=maxf(0.0,float(npc.wait)-dt)
		npc.look_in=maxf(0.0,float(npc.look_in)-dt)
		npc.replan-=dt
		var schedule:String="day" if game.phase=="day" else "shelter"
		if str(npc.schedule)!=schedule:
			npc.schedule=schedule
			npc.path=PackedVector2Array();npc.replan=0.0;npc.wait=0.0
			if schedule=="shelter":
				npc.goal=_legal_near(game,str(name),npc.refuge,52.0)
				npc.activity="return_to_camp"
			else:
				npc.goal=npc.home
				npc.activity="walk"
				npc.wait=rng.randf_range(0.6,2.7)
		if schedule=="shelter" and npc.p.distance_to(npc.goal)<13.0:
			npc.activity="shelter"
			_look(npc,dt)
			continue
		if schedule=="day":
			if float(npc.wait)>0.0:
				_look(npc,dt)
				continue
			if npc.p.distance_to(npc.goal)<14.0 or npc.path.is_empty() and float(npc.stuck)>1.4:
				if str(npc.activity)=="walk":
					npc.activity="rest"
					npc.wait=rng.randf_range(1.5,5.8) if name=="Rowan" else rng.randf_range(0.9,4.1)
					npc.stuck=0.0
					continue
				npc.goal=_day_goal(game,str(name),npc)
				npc.activity="walk"
				npc.path=PackedVector2Array();npc.replan=0.0
		var speed:float=float(npc.speed)*float(npc.pace)
		if schedule=="shelter":speed=maxf(speed,55.0)
		_move(game,str(name),npc,speed,dt)
	game.npc_home=game.npc_states.Rowan.p
	game.npc_position=game.npc_states.Ash.p

func _day_goal(game:Variant,name:String,npc:Dictionary) -> Vector2:
	var leg:Vector2=npc.leg
	for attempt in range(36):
		var angle:float=rng.randf()*TAU
		var goal:Vector2=npc.p+Vector2(cos(angle),sin(angle))*rng.randf_range(leg.x,leg.y)
		# Ash explores farther from the camp. Rowan works around the camp yard.
		if goal.distance_to(npc.home)>float(npc.roam_radius):continue
		if goal.distance_to(npc.previous_goal)<42.0:continue
		if not game.npc_walkable(goal,name) or not _reachable(game,npc.p,goal):continue
		npc.previous_goal=goal
		npc.goals_chosen=int(npc.goals_chosen)+1
		return goal
	return npc.p

func _legal_near(game:Variant,name:String,wanted:Vector2,radius:float) -> Vector2:
	var npc:Dictionary=game.npc_states[name]
	if game.npc_walkable(wanted,name) and _reachable(game,npc.p,wanted):return wanted
	for attempt in range(40):
		var angle:float=rng.randf()*TAU
		var candidate:Vector2=wanted+Vector2(cos(angle),sin(angle))*rng.randf_range(12.0,radius)
		if game.npc_walkable(candidate,name) and _reachable(game,npc.p,candidate):return candidate
	return npc.p

func _reachable(game:Variant,start:Vector2,finish:Vector2) -> bool:
	var from:Vector2i=game.nav_cell(start)
	var to:Vector2i=game.nav_cell(finish)
	return from.x>=0 and to.x>=0 and not game.nav_grid.get_id_path(from,to).is_empty()

func _look(npc:Dictionary,dt:float) -> void:
	if float(npc.look_in)>0.0:return
	npc.look_in=rng.randf_range(1.1,3.1)
	var angle:float=atan2(npc.facing.x,npc.facing.y)+rng.randf_range(-0.65,0.65)
	# Feet remain planted while listening; walking is never played in place.
	npc.facing=Vector2(sin(angle),cos(angle))

func _move(game:Variant,name:String,npc:Dictionary,speed:float,dt:float) -> void:
	if float(npc.replan)<=0.0 or int(npc.nav_revision)!=int(game.nav_revision):
		var from:Vector2i=game.nav_cell(npc.p)
		var to:Vector2i=game.nav_cell(npc.goal)
		npc.path=game.nav_grid.get_point_path(from,to) if from.x>=0 and to.x>=0 else PackedVector2Array()
		npc.cursor=0;npc.nav_revision=game.nav_revision;npc.replan=rng.randf_range(1.1,1.8)
	var path:PackedVector2Array=npc.path
	while int(npc.cursor)<path.size() and npc.p.distance_to(path[int(npc.cursor)])<4.0:npc.cursor+=1
	if int(npc.cursor)>=path.size():
		npc.stuck+=dt
		return
	var direction:Vector2=path[int(npc.cursor)]-npc.p
	var previous:Vector2=npc.p
	var step:Vector2=direction.normalized()*minf(direction.length(),speed*dt)
	var substeps:int=maxi(1,ceili(step.length()/1.5))
	var part:Vector2=step/float(substeps)
	for index in range(substeps):
		if game.npc_walkable(npc.p+part,name):npc.p+=part
		elif game.npc_walkable(npc.p+Vector2(part.x,0),name):npc.p.x+=part.x
		elif game.npc_walkable(npc.p+Vector2(0,part.y),name):npc.p.y+=part.y
	var walked:float=npc.p.distance_to(previous)
	if walked>0.01:
		npc.moving=true
		npc.walk=fposmod(float(npc.walk)+walked,WALK_STRIDE)
		var angle:float=lerp_angle(atan2(npc.facing.x,npc.facing.y),atan2(direction.x,direction.y),1.0-exp(-dt*10.0))
		npc.facing=Vector2(sin(angle),cos(angle))
		npc.stuck=0.0
	else:
		npc.replan=minf(float(npc.replan),0.15)
		npc.stuck+=dt
		if float(npc.stuck)>1.4:
			# Choose another clear point instead of pushing forever or teleporting.
			if str(npc.schedule)=="shelter":npc.goal=_legal_near(game,name,npc.refuge,75.0)
			else:npc.goal=_day_goal(game,name,npc)
			npc.stuck=0.0;npc.replan=0.0
