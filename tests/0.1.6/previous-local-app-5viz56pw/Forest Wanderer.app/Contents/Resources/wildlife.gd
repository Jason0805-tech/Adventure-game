extends RefCounted
## Autonomous ground-plane wildlife. No drawing or resource loading happens here.
## The host owns time/UI; a paused update never advances encounters or spawning.
const Data = preload("res://wildlife_data.gd")
const Geometry = preload("res://world_geometry.gd")
var animals:Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var next_uid := 1
var period := ""
var respawn_in := 0.0
var player_hit_grace := 0.0
var kills:Dictionary = {}
var last_events:Array[Dictionary] = []
var game_ref:WeakRef

func setup(game:Variant,seed_value:int) -> void:
	game_ref = weakref(game)
	if seed_value == 0:rng.randomize()
	else:rng.seed = seed_value ^ 0x16A71E
	animals.clear()
	kills.clear()
	last_events.clear()
	next_uid = 1
	period = ""
	respawn_in = 0.0
	player_hit_grace = 0.0

func entries() -> Array[Dictionary]:
	var output:Array[Dictionary] = []
	for animal in animals:
		var spec:Dictionary = Data.info(str(animal.species))
		var warning:bool = str(animal.state) == "windup"
		output.append({"uid":int(animal.uid),"species":str(animal.species),
			"p":animal.p,"facing":animal.facing,"moving":bool(animal.moving),
			"frame":int(float(animal.walk)/float(spec.stride)*8.0)%8 if animal.moving else 8,
			"state":str(animal.state),"alpha":minf(1.0,float(animal.age)/0.7),
			"hitflash":float(animal.hitflash),"health":float(animal.hp),
			"max_health":float(spec.health),"height":float(spec.height),
			"warning":warning,"attack_progress":1.0-float(animal.timer)/float(spec.get("windup",1.0)) if warning else 0.0})
	return output

func footprint(animal:Dictionary,at:Vector2) -> PackedVector2Array:
	var ground:Vector4=Data.ground(str(animal.species),animal.get("facing",Vector2.DOWN))
	return Geometry.capsule_polygon(at+Vector2(ground.x,ground.y),ground.z,ground.w,8)

func body_blocked(p:Vector2,exclude_uid:int=-1,candidate_polygon:PackedVector2Array=PackedVector2Array()) -> bool:
	var game:Variant = game_ref.get_ref() if game_ref != null else null
	if game == null:return false
	var polygon:PackedVector2Array = game.feet_polygon(p) if candidate_polygon.is_empty() else candidate_polygon
	var bounds:Rect2 = Geometry.polygon_bounds(polygon)
	for animal in animals:
		if int(animal.uid) == exclude_uid:continue
		var shape:PackedVector2Array = footprint(animal,animal.p)
		if Geometry.bounds_overlap(bounds,Geometry.polygon_bounds(shape)) and Geometry.polygons_overlap(polygon,shape):return true
	return false

func _ground_clear(game:Variant,animal:Dictionary,p:Vector2) -> bool:
	# Use the same real contours as the player, but the species' own boot capsule.
	# Smaller rabbits can use smaller gaps; the bear cannot inherit human clearance.
	var polygon:PackedVector2Array = footprint(animal,p)
	var bounds:Rect2 = Geometry.polygon_bounds(polygon)
	if bounds.position.x<32 or bounds.position.y<40 or bounds.end.x>2168 or bounds.end.y>1468:return false
	for body in game.solid_bodies:
		if game.body_active(body) and Geometry.bounds_overlap(bounds,body.bounds) and Geometry.polygons_overlap(polygon,body.polygon):return false
	return true

func _walkable(game:Variant,animal:Dictionary,p:Vector2,spawning:bool=false) -> bool:
	if not _ground_clear(game,animal,p):return false
	if p.distance_to(Data.CAMP) < Data.CAMP_SAFE_RADIUS:return false
	if p.distance_to(Data.GATE_PASSAGE) < 84.0:return false
	var polygon:PackedVector2Array = footprint(animal,p)
	if Geometry.polygons_overlap(polygon,game.feet_polygon(game.player)):return false
	for name in game.npc_states:
		var npc_p:Vector2 = game.npc_states[name].p
		if spawning and p.distance_to(npc_p) < 90.0:return false
		if Geometry.polygons_overlap(polygon,game.feet_polygon(npc_p)):return false
	return not body_blocked(p,int(animal.uid),polygon)

func _line_clear(game:Variant,start:Vector2,finish:Vector2) -> bool:
	for body in game.solid_bodies:
		if game.body_active(body) and Geometry.segment_intersects_polygon(start,finish,body.polygon):return false
	return true

func _spawn_one(game:Variant,species:String) -> bool:
	var spec:Dictionary = Data.info(species)
	for attempt in range(140):
		var habitat:Rect2 = spec.habitats[rng.randi_range(0,spec.habitats.size()-1)]
		var p:Vector2 = habitat.position+Vector2(rng.randf(),rng.randf())*habitat.size
		if p.distance_to(game.player) < (360.0 if spec.predator else 170.0):continue
		var candidate:Dictionary = {"uid":next_uid,"species":species,"p":p,"facing":Vector2.DOWN.rotated(rng.randf()*TAU)}
		if not _walkable(game,candidate,p,true):continue
		# Do not populate disconnected painted pockets that cannot join real routes.
		if game.nav_grid != null:
			var from:Vector2i = game.nav_cell(game.player)
			var to:Vector2i = game.nav_cell(p)
			if from.x < 0 or to.x < 0 or game.nav_grid.get_id_path(from,to).is_empty():continue
		animals.append({"uid":next_uid,"species":species,"p":p,"home":p,
			"facing":candidate.facing,"hp":float(spec.health),
			"moving":false,"walk":0.0,"age":0.0,"hitflash":0.0,"hurt_grace":0.0,
			"state":"idle","timer":rng.randf_range(0.7,2.8),"goal":p,
			"path":PackedVector2Array(),"cursor":0,"repath":0.0,"stuck":0.0,
			"locked_aim":p,"nav_revision":int(game.nav_revision)})
		next_uid += 1
		return true
	return false

func _populate(game:Variant) -> void:
	for species in Data.SPECIES_ORDER:
		if not Data.active(species,period):continue
		var count := 0
		for animal in animals:
			if str(animal.species) == species:count += 1
		while count < int(Data.info(species).cap):
			if not _spawn_one(game,species):break
			count += 1

func update(game:Variant,delta:float,active_period:String,simulation_enabled:bool=true) -> void:
	game_ref = weakref(game)
	if period != active_period:
		period = active_period
		animals = animals.filter(func(animal):return Data.active(str(animal.species),period))
		_populate(game)
		respawn_in = Data.RESPAWN_DELAY
	# Ecology synchronizes even at a zero-delta dawn/setup. Only timers and
	# behavior freeze; wrong-time species must never retain invisible colliders.
	if not simulation_enabled or delta <= 0.0:return
	var dt:float = minf(delta,0.10) # Never burst an entire attack after a stalled frame.
	last_events.clear()
	respawn_in -= dt
	player_hit_grace = maxf(0.0,player_hit_grace-dt)
	if respawn_in <= 0.0:
		_populate(game)
		respawn_in = Data.RESPAWN_DELAY
	for animal in animals:
		_update_animal(game,animal,dt)

func _new_wander_goal(game:Variant,animal:Dictionary) -> Vector2:
	for attempt in range(14):
		var goal:Vector2 = animal.home+Vector2(rng.randf_range(-140,140),rng.randf_range(-120,120))
		if _walkable(game,animal,goal):return goal
	return animal.p

func _set_state(animal:Dictionary,state:String,timer:float=0.0) -> void:
	if str(animal.state) != state:
		animal.state = state
		animal.path = PackedVector2Array()
		animal.cursor = 0
		animal.repath = 0.0
		animal.stuck = 0.0
		animal.timer = timer

func _try_facing(game:Variant,animal:Dictionary,wanted:Vector2) -> bool:
	if wanted.length_squared()<0.001:return true
	var previous:Vector2=animal.facing
	animal.facing=wanted.normalized()
	# Side-view paws span farther than front-view paws. Turning is a physical
	# move too: never expand that ground envelope into a trunk, actor or water.
	if not _walkable(game,animal,animal.p):
		animal.facing=previous
		return false
	return true

func _update_animal(game:Variant,animal:Dictionary,dt:float) -> void:
	var spec:Dictionary = Data.info(str(animal.species))
	animal.moving = false
	animal.age += dt
	animal.hitflash = maxf(0.0,float(animal.hitflash)-dt)
	animal.hurt_grace = maxf(0.0,float(animal.hurt_grace)-dt)
	animal.timer = maxf(0.0,float(animal.timer)-dt)
	animal.repath -= dt
	var distance:float = animal.p.distance_to(game.player)
	var safe:bool = game.player.distance_to(Data.CAMP) < Data.CAMP_SAFE_RADIUS+18.0
	var clear_sight:bool = distance < float(spec.notice) and _line_clear(game,animal.p,game.player)
	if spec.predator:
		if animal.state == "windup":
			# Feet stop during a clearly telegraphed bite/swipe. Aim locks on entry;
			# stepping sideways or outside range during this window avoids the hit.
			if safe:
				_set_state(animal,"return");animal.goal=animal.home
			elif float(animal.timer) <= 0.0:
				var aim:Vector2 = animal.locked_aim-animal.p
				var relative:Vector2 = game.player-animal.p
				var in_arc:bool = aim.normalized().dot(relative.normalized()) >= 0.55
				if distance <= float(spec.attack_range)+3.0 and in_arc and _line_clear(game,animal.p,game.player) and player_hit_grace <= 0.0:
					var dealt:float = float(spec.damage)
					if game.has_method("wildlife_damage"):
						var result:Variant = game.wildlife_damage(dealt,str(animal.species))
						if result is float or result is int:dealt=maxf(0.0,float(result))
					else:game.take_damage(dealt)
					player_hit_grace = Data.PLAYER_HIT_GRACE
					last_events.append({"type":"player_hit","species":animal.species,"damage":dealt})
				_set_state(animal,"recover",float(spec.recovery))
			return
		if animal.state == "recover":
			if float(animal.timer) > 0.0:return
			_set_state(animal,"idle",0.15)
		if (safe and animal.state == "chase") or animal.p.distance_to(animal.home) > 480.0:
			_set_state(animal,"return");animal.goal=animal.home
		elif not safe and clear_sight and float(animal.age) >= Data.SPAWN_GRACE:
			if distance <= float(spec.attack_range) and _line_clear(game,animal.p,game.player):
				_set_state(animal,"windup",float(spec.windup))
				animal.locked_aim = game.player
				_try_facing(game,animal,(game.player-animal.p).normalized())
				return
			_set_state(animal,"chase");animal.goal=game.player
		elif animal.state == "chase":
			_set_state(animal,"return");animal.goal=animal.home
	else:
		if clear_sight:
			var away:Vector2 = (animal.p-game.player).normalized()
			if away.length_squared() < 0.1:away=Vector2.RIGHT
			_set_state(animal,"flee",2.0)
			animal.timer = 2.0
			animal.goal = animal.p+away*180.0
		elif animal.state == "flee" and float(animal.timer) <= 0.0:
			_set_state(animal,"idle",rng.randf_range(1.0,3.0))
	if animal.state == "idle":
		if float(animal.timer) > 0.0:return
		_set_state(animal,"wander")
		animal.goal = _new_wander_goal(game,animal)
	if animal.state == "return" and animal.p.distance_to(animal.home) < 30.0:
		_set_state(animal,"idle",rng.randf_range(1.2,3.0));return
	if animal.state == "wander" and animal.p.distance_to(animal.goal) < 12.0:
		_set_state(animal,"idle",rng.randf_range(1.3,3.8));return
	var speed:float = float(spec.speed)
	if animal.state == "flee":speed=float(spec.flee_speed)
	elif animal.state == "chase":speed=float(spec.chase_speed)
	_move_toward(game,animal,animal.goal,speed,dt)

func _replan(game:Variant,animal:Dictionary,goal:Vector2) -> void:
	animal.repath = 0.75+rng.randf()*0.35
	animal.nav_revision = int(game.nav_revision)
	if _line_clear(game,animal.p,goal):
		animal.path = PackedVector2Array([goal]);animal.cursor=0;return
	var from:Vector2i = game.nav_cell(animal.p)
	var to:Vector2i = game.nav_cell(goal)
	animal.path = game.nav_grid.get_point_path(from,to) if from.x >= 0 and to.x >= 0 else PackedVector2Array()
	animal.cursor = 0

func _move_toward(game:Variant,animal:Dictionary,goal:Vector2,speed:float,dt:float) -> void:
	if float(animal.repath) <= 0.0 or int(animal.nav_revision) != int(game.nav_revision):_replan(game,animal,goal)
	var path:PackedVector2Array = animal.path
	while int(animal.cursor) < path.size() and animal.p.distance_to(path[int(animal.cursor)]) < 4.0:animal.cursor += 1
	if int(animal.cursor) >= path.size():
		animal.repath = minf(float(animal.repath),0.15)
		animal.stuck += dt
		if float(animal.stuck) > 1.2 and animal.state in ["wander","return"]:
			_set_state(animal,"idle",rng.randf_range(0.7,1.8))
		return
	var target:Vector2 = path[int(animal.cursor)]
	var direction:Vector2 = target-animal.p
	var desired_angle:float=lerp_angle(atan2(animal.facing.x,animal.facing.y),atan2(direction.x,direction.y),1.0-exp(-dt*12.0))
	_try_facing(game,animal,Vector2(sin(desired_angle),cos(desired_angle)))
	var step:Vector2 = direction.normalized()*minf(direction.length(),speed*dt)
	var previous:Vector2 = animal.p
	var substeps:int = maxi(1,ceili(step.length()/1.5))
	var part:Vector2 = step/float(substeps)
	for index in range(substeps):
		if _walkable(game,animal,animal.p+part):animal.p+=part
		elif _walkable(game,animal,animal.p+Vector2(part.x,0)):animal.p.x+=part.x
		elif _walkable(game,animal,animal.p+Vector2(0,part.y)):animal.p.y+=part.y
	var walked:float = animal.p.distance_to(previous)
	if walked > 0.01:
		animal.moving = true
		animal.walk = fposmod(float(animal.walk)+walked,float(Data.info(str(animal.species)).stride))
		var heading:Vector2 = animal.p-previous
		var angle:float = lerp_angle(atan2(animal.facing.x,animal.facing.y),atan2(heading.x,heading.y),1.0-exp(-dt*12.0))
		_try_facing(game,animal,Vector2(sin(angle),cos(angle)))
		animal.stuck = 0.0
	else:
		animal.repath = minf(float(animal.repath),0.15)
		animal.stuck += dt
		if float(animal.stuck) > 0.9:
			# A larger bear can reject a human-sized navigation corner. Pick a
			# fresh legal patrol goal; never teleport or force it through that wall.
			if animal.state in ["wander","return"]:
				animal.goal = _new_wander_goal(game,animal)
				animal.stuck = 0.0
			elif animal.state == "flee":
				animal.goal = animal.p+(animal.goal-animal.p).rotated(rng.randf_range(-1.1,1.1)).normalized()*140.0
				animal.stuck = 0.0

func target_near(origin:Vector2,facing:Vector2,reach:float=70.0) -> Dictionary:
	var game:Variant = game_ref.get_ref() if game_ref != null else null
	var best:Dictionary = {}
	var closest:float = reach
	for animal in animals:
		var relative:Vector2 = animal.p-origin
		if relative.length() > closest or facing.normalized().dot(relative.normalized()) < 0.10:continue
		if game != null and not _line_clear(game,origin,animal.p):continue
		closest = relative.length()
		best = {"uid":int(animal.uid),"species":str(animal.species),"pos":animal.p,"kind":"wildlife"}
	return best

func attack(game:Variant,origin:Vector2,facing:Vector2,damage:float=18.0,reach:float=64.0,arc_dot:float=0.10) -> Dictionary:
	var hit_ids:Array[int] = []
	var killed:Array[String] = []
	var direction:Vector2 = facing.normalized()
	for animal in animals:
		var relative:Vector2 = animal.p-origin
		if relative.length() > reach or direction.dot(relative.normalized()) < arc_dot:continue
		if float(animal.hurt_grace) > 0.0 or not _line_clear(game,origin,animal.p):continue
		animal.hp -= maxf(0.0,damage)
		animal.hitflash = 0.24
		animal.hurt_grace = 0.30
		hit_ids.append(int(animal.uid))
		if float(animal.hp) <= 0.0:
			killed.append(str(animal.species))
			kills[animal.species] = int(kills.get(animal.species,0))+1
		else:
			# A landed blow interrupts an attack; recovery prevents an immediate bite.
			if bool(Data.info(str(animal.species)).predator):_set_state(animal,"recover",0.75)
			else:
				_set_state(animal,"flee",2.0)
				animal.goal = animal.p+(animal.p-origin).normalized()*180.0
	animals = animals.filter(func(animal):return float(animal.hp)>0.0)
	return {"hits":hit_ids.size(),"hit_ids":hit_ids,"kills":killed}
