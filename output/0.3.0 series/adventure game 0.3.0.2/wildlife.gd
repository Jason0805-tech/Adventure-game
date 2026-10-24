extends RefCounted
## Autonomous ground-plane wildlife. No drawing or resource loading happens here.
## The host owns time/UI; a paused update never advances encounters or spawning.
const Data = preload("res://wildlife_data.gd")
const Geometry = preload("res://world_geometry.gd")
const Balance = preload("res://survival_balance.gd")
const Predator = preload("res://predator_behavior.gd")
var animals:Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var next_uid := 1
var period := ""
var respawn_in := 0.0
var player_hit_grace := 0.0
var kills:Dictionary = {}
var last_events:Array[Dictionary] = []
var game_ref:WeakRef
var navigation_cache:Dictionary={}
var navigation_build_usec:Dictionary={}
var navigation_cache_hits:=0
# v0.1.9 night hunting. The player leaves a scent trail (positions sampled every
# 2 s); predators follow OLD trail points, never the live position. Noise from
# chopping, mining, fighting and sprinting draws them to its source.
const SCENT_INTERVAL := 2.0
const SCENT_LENGTH := 30
var scent: Array[Vector2] = []
var scent_in := 0.0
var noises: Array[Dictionary] = []

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
	navigation_cache.clear()
	navigation_build_usec.clear();navigation_cache_hits=0

func entries() -> Array[Dictionary]:
	var output:Array[Dictionary] = []
	for animal in animals:
		var spec:Dictionary = Data.info(str(animal.species))
		var warning:bool = str(animal.state) in ["windup","charge_warn"]
		output.append({"uid":int(animal.uid),"species":str(animal.species),"shadow":bool(animal.get("shadow",false)),
			"p":animal.p,"facing":animal.facing,"moving":bool(animal.moving),
			"frame":int(float(animal.walk)/float(spec.stride)*8.0)%8 if animal.moving else 8,
			"gait_phase":fposmod(float(animal.walk)/float(spec.stride),1.0),
			"gait_rate":float(animal.get("gait_rate",0.0)),"activity":str(animal.get("activity","rest")),
			"state":str(animal.state),"alpha":minf(1.0,float(animal.age)/0.7),
			"hitflash":float(animal.hitflash),"health":float(animal.hp),
			"max_health":42.0 if animal.get("shadow",false) else float(spec.health),"height":float(spec.height),
			"warning":warning,"attack_progress":1.0-float(animal.timer)/float(animal.get("warning_duration",spec.get("windup",1.0))) if warning else 0.0})
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
	if bounds.position.x<32 or bounds.position.y<40 or bounds.end.x>Data.WORLD_SIZE.x-32 or bounds.end.y>Data.WORLD_SIZE.y-32:return false
	for body in _bodies(game,bounds):
		if game.body_active(body) and Geometry.bounds_overlap(bounds,body.bounds) and Geometry.polygons_overlap(polygon,body.polygon):return false
	return true

func _bodies(game:Variant,rect:Rect2) -> Array:
	# Spatial index when the game has one (v0.3.0), else every body.
	return game.bodies_in(rect) if game.has_method("bodies_in") else game.solid_bodies

func _walkable(game:Variant,animal:Dictionary,p:Vector2,spawning:bool=false) -> bool:
	if not _ground_clear(game,animal,p):return false
	if p.distance_to(Data.GATE_PASSAGE) < 84.0:return false
	var polygon:PackedVector2Array = footprint(animal,p)
	if Geometry.polygons_overlap(polygon,game.feet_polygon(game.player)):return false
	for name in game.npc_states:
		var npc_p:Vector2 = game.npc_states[name].p
		if spawning and p.distance_to(npc_p) < 90.0:return false
		if Geometry.polygons_overlap(polygon,game.feet_polygon(npc_p)):return false
	return not body_blocked(p,int(animal.uid),polygon)

func _line_clear(game:Variant,start:Vector2,finish:Vector2) -> bool:
	for body in _bodies(game,Rect2(start,Vector2.ZERO).expand(finish).grow(1.0)):
		if game.body_active(body) and Geometry.segment_intersects_polygon(start,finish,body.polygon):return false
	return true

func _travel_clear(game:Variant,animal:Dictionary,start:Vector2,finish:Vector2) -> bool:
	# Seeing past a trunk does not mean a wide animal can walk past it. Check a
	# swept ground envelope before choosing a direct shortcut; never sprite bounds.
	if not _line_clear(game,start,finish):return false
	var candidate:Dictionary={"species":animal.species,"facing":(finish-start).normalized()}
	var steps:int=maxi(1,ceili(start.distance_to(finish)/6.0))
	for index in range(steps+1):
		var p:Vector2=start.lerp(finish,float(index)/float(steps))
		if not _ground_clear(game,candidate,p):return false
		if p.distance_to(Data.GATE_PASSAGE)<84.0:return false
	return true

func _species_navigation(game:Variant,species:String) -> AStarGrid2D:
	var cached:Dictionary=navigation_cache.get(species,{})
	if int(cached.get("revision",-1))==int(game.nav_revision):
		navigation_cache_hits+=1
		return cached.grid
	var started:int=Time.get_ticks_usec()
	var grid:=AStarGrid2D.new()
	grid.region=game.nav_grid.region;grid.cell_size=game.nav_grid.cell_size;grid.offset=game.nav_grid.offset
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;grid.update()
	var extent:=Vector2.ZERO
	for ground in Data.info(species).ground:
		extent.x=maxf(extent.x,absf(ground.x)+ground.z+2.0)
		extent.y=maxf(extent.y,absf(ground.y)+ground.w+2.0)
	var front:Vector4=Data.ground(species,Vector2.DOWN)
	var minimum:=Vector2(front.z+absf(front.x)+2.0,front.w+absf(front.y)+2.0)
	# Wolves fit the wide-clearance graph throughout the forest. Large bears
	# need to be allowed through narrower front-facing corridors, with costly
	# corner cells encouraging a wider turn where space exists.
	if species=="wolf":minimum=extent
	# These conservative rectangles belong only to the navigation planner. Exact
	# authored ground polygons and heading-dependent paws still decide every step.
	# A bear plans farther from tree corners than a rabbit, avoiding narrow human
	# waypoints that it cannot physically reach. Cache once per map revision.
	for body in game.solid_bodies:
		if not game.body_active(body):continue
		var bounds:Rect2=Rect2(body.bounds.position-extent,body.bounds.size+extent*2.0)
		var solid_bounds:Rect2=Rect2(body.bounds.position-minimum,body.bounds.size+minimum*2.0)
		var lo:Vector2i=Vector2i(floori((bounds.position.x-grid.offset.x)/grid.cell_size.x),floori((bounds.position.y-grid.offset.y)/grid.cell_size.y))
		var hi:Vector2i=Vector2i(ceili((bounds.end.x-grid.offset.x)/grid.cell_size.x),ceili((bounds.end.y-grid.offset.y)/grid.cell_size.y))
		for y in range(maxi(0,lo.y),mini(grid.region.end.y,hi.y+1)):
			for x in range(maxi(0,lo.x),mini(grid.region.end.x,hi.x+1)):
				var id:=Vector2i(x,y)
				var p:Vector2=grid.get_point_position(id)
				if solid_bounds.has_point(p):grid.set_point_solid(id,true)
				elif bounds.has_point(p):grid.set_point_weight_scale(id,maxf(6.0,grid.get_point_weight_scale(id)))
	for y in range(grid.region.end.y):
		for x in range(grid.region.end.x):
			var id:=Vector2i(x,y);var p:Vector2=grid.get_point_position(id)
			if p.x-minimum.x<32 or p.y-minimum.y<40 or p.x+minimum.x>Data.WORLD_SIZE.x-32 or p.y+minimum.y>Data.WORLD_SIZE.y-32 or p.distance_to(Data.GATE_PASSAGE)<84.0:grid.set_point_solid(id,true)
	navigation_cache[species]={"revision":int(game.nav_revision),"grid":grid}
	navigation_build_usec[species]=Time.get_ticks_usec()-started
	return grid

func _species_cell(grid:AStarGrid2D,p:Vector2) -> Vector2i:
	var base:=Vector2i(floori((p.x-grid.offset.x)/grid.cell_size.x),floori((p.y-grid.offset.y)/grid.cell_size.y))
	var nearest:=Vector2i(-1,-1);var closest:=INF
	for dy in range(-8,9):
		for dx in range(-8,9):
			var id:Vector2i=base+Vector2i(dx,dy)
			if not grid.region.has_point(id) or grid.is_point_solid(id):continue
			var distance:float=p.distance_squared_to(grid.get_point_position(id))
			if distance<closest:closest=distance;nearest=id
	return nearest

func _spawn_one(game:Variant,species:String,prefer_lantern:bool=true) -> bool:
	var spec:Dictionary = Data.info(species)
	var nearby_wolf:bool=prefer_lantern and species=="wolf" and game.night>=2
	for existing in animals:
		if existing.species=="wolf" and not existing.get("shadow",false):nearby_wolf=false
	var near_player:bool=spec.predator and period=="night"
	for attempt in range(140):
		var habitat:Rect2 = spec.habitats[rng.randi_range(0,spec.habitats.size()-1)]
		var p:Vector2 = habitat.position+Vector2(rng.randf(),rng.randf())*habitat.size
		if near_player and attempt<90:
			# Hunters arrive from the woods around where the player is, out of sight.
			p=game.player+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(480.0,820.0)
			if not Rect2(Vector2(60,80),Data.WORLD_SIZE-Vector2(120,140)).has_point(p):continue
			if p.distance_to(Data.CAMP)<260.0:continue
		elif nearby_wolf and attempt<110 and p.distance_to(Data.CAMP)>640:continue
		if p.distance_to(game.player) < (360.0 if spec.predator else 170.0):continue
		var candidate:Dictionary = {"uid":next_uid,"species":species,"p":p,"facing":Vector2.DOWN.rotated(rng.randf()*TAU)}
		if not _walkable(game,candidate,p,true):continue
		# Do not populate disconnected painted pockets that cannot join real routes.
		if game.nav_grid != null:
			var from:Vector2i = game.nav_cell(game.player)
			var to:Vector2i = game.nav_cell(p)
			if from.x < 0 or to.x < 0 or game.nav_grid.get_id_path(from,to).is_empty():continue
		_register_animal(game,species,p,candidate.facing,nearby_wolf)
		return true
	return false

func _register_animal(game:Variant,species:String,p:Vector2,direction:Vector2,camp_visit:bool=false) -> Dictionary:
	var animal:Dictionary={"uid":next_uid,"species":species,"p":p,"home":p,
		"facing":direction,"hp":float(Data.info(species).health),
		"moving":false,"walk":0.0,"age":0.0,"hitflash":0.0,"hurt_grace":0.0,
		"state":"idle","timer":rng.randf_range(0.7,2.8),"goal":p,
		"path":PackedVector2Array(),"cursor":0,"repath":0.0,"stuck":0.0,
		"locked_aim":p,"nav_revision":int(game.nav_revision),"camp_visit":camp_visit}
	_initialize_traits(animal)
	animals.append(animal);next_uid+=1
	return animal

func night_hunt_chance(game:Variant) -> float:
	# How eagerly an unaware predator follows the trail; rises night by night.
	var bonus: float = float(game.night_mod("hunt_bonus", 0.0)) if game.has_method("night_mod") else 0.0
	return minf(0.95, [0.30,0.45,0.60,0.70][clampi(int(game.night)-1,0,3)] + bonus)

func scent_point(min_age:float,max_age:float) -> Vector2:
	# An old trail point: where the player WAS min_age..max_age seconds ago.
	if scent.is_empty():return Vector2.INF
	var newest:int=scent.size()-1
	var a:int=clampi(newest-int(max_age/SCENT_INTERVAL),0,newest)
	var b:int=clampi(newest-int(min_age/SCENT_INTERVAL),0,newest)
	return scent[rng.randi_range(mini(a,b),maxi(a,b))]

func make_noise(game:Variant,origin:Vector2,radius:float,kind:String="noise") -> int:
	# Predators within earshot that are not already fighting come to look.
	var drawn:=0
	for a in animals:
		if not Data.info(str(a.species)).get("predator",false) or a.get("shadow",false):continue
		if str(a.state) in ["chase","windup","charge_warn","charge","recover","exhausted"]:continue
		if a.p.distance_to(origin)>radius:continue
		_initialize_traits(a)
		a.last_seen=origin
		a.awareness=maxf(float(a.awareness),float(a.temperament.memory)+1.5)
		a.hunting=true
		_set_state(a,"investigate",4.0)
		a.goal=origin;a.activity="listen";a.repath=0.0
		drawn+=1
	noises.append({"p":origin,"radius":radius,"kind":kind,"drawn":drawn})
	if noises.size()>20:noises.pop_front()
	return drawn

func spawn_wave(game:Variant,center:Vector2,species:String,count:int) -> int:
	# The Last Watch: hunters break from the treeline around the beacon and
	# make for the fire. Waves ignore the normal cap but never appear in view
	# of the player (at least 380 away) or on an unreachable patch.
	var spawned:=0
	for n in range(count):
		for attempt in range(80):
			var p:Vector2=center+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(520.0,760.0)
			if not Rect2(Vector2(60,80),Data.WORLD_SIZE-Vector2(120,140)).has_point(p):continue
			if p.distance_to(game.player)<380.0:continue
			var candidate:Dictionary={"uid":next_uid,"species":species,"p":p,"facing":(center-p).normalized()}
			if not _walkable(game,candidate,p,true):continue
			if not _reachable(game,p,center):continue
			var a:Dictionary=_register_animal(game,species,p,(center-p).normalized())
			a.age=10.0;a.hunting=true;a.wave=true;a.activity="track"
			a.home=center
			_set_state(a,"wander")
			a.goal=center+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(130.0,200.0)
			a.repath=0.0
			spawned+=1
			break
	return spawned

func _recycle_far_hunters(game:Variant,dt:float) -> void:
	# A predator idling far from the player for a long time slips away; the
	# population then refills from the woods nearer the player.
	if period!="night":return
	for a in animals:
		if not Data.info(str(a.species)).get("predator",false) or a.get("shadow",false):continue
		if a.p.distance_to(game.player)>1250.0 and str(a.state) in ["idle","wander","return"]:
			a.far_time=float(a.get("far_time",0.0))+dt
		else:a.far_time=0.0
	var before:int=animals.size()
	animals=animals.filter(func(a):return float(a.get("far_time",0.0))<22.0)
	if animals.size()<before:respawn_in=minf(respawn_in,rng.randf_range(4.0,8.0))

func _populate(game:Variant) -> void:
	for species in Data.SPECIES_ORDER:
		if not Data.active(species,period):continue
		var count := 0
		for animal in animals:
			if str(animal.species) == species and not animal.get("shadow",false):count += 1
		var cap: int = int(Balance.night_profile(game.night).wolves) if species == "wolf" else int(Data.info(species).cap)
		if species == "wolf" and game.has_method("night_mod"): cap += int(game.night_mod("extra_wolves", 0))
		while count < cap:
			if not _spawn_one(game,species):break
			count += 1

func update(game:Variant,delta:float,active_period:String,simulation_enabled:bool=true) -> void:
	game_ref = weakref(game)
	if period != active_period:
		period = active_period
		animals = animals.filter(func(animal):return Data.active(str(animal.species),period))
		_populate(game)
		respawn_in = rng.randf_range(respawn_delay(game)*0.90,respawn_delay(game)*1.10)
	# Ecology synchronizes even at a zero-delta dawn/setup. Only timers and
	# behavior freeze; wrong-time species must never retain invisible colliders.
	if not simulation_enabled or delta <= 0.0:return
	var dt:float = minf(delta,0.10) # Never burst an entire attack after a stalled frame.
	last_events.clear()
	respawn_in -= dt
	player_hit_grace = maxf(0.0,player_hit_grace-dt)
	if respawn_in <= 0.0:
		_populate(game)
		respawn_in = rng.randf_range(respawn_delay(game)*0.90,respawn_delay(game)*1.10)
	if period=="night":
		scent_in-=dt
		if scent_in<=0.0:
			scent_in=SCENT_INTERVAL
			scent.append(game.player)
			if scent.size()>SCENT_LENGTH:scent.pop_front()
		_recycle_far_hunters(game,dt)
	else:
		scent.clear()
	for animal in animals:
		_update_animal(game,animal,dt)

func _initialize_traits(animal:Dictionary) -> void:
	# Individual temperament is rolled once, not every frame. Random decisions
	# produce purposeful legs of travel instead of twitching or a four-point loop.
	if animal.has("temperament"):return
	var spec:Dictionary=Data.info(str(animal.species))
	var ecology:Dictionary=spec.ecology
	animal.temperament={"pace":rng.randf_range(0.89,1.09),"notice":rng.randf_range(0.91,1.11),
		"roam":float(ecology.roam)*rng.randf_range(0.88,1.12),"patience":rng.randf_range(0.8,1.25),
		"memory":float(ecology.memory)*rng.randf_range(0.85,1.15),"flight_side":-1.0 if rng.randf()<0.5 else 1.0}
	animal.last_seen=animal.p
	animal.awareness=0.0
	animal.decision=0.0
	animal.look_in=rng.randf_range(0.7,2.6)
	animal.scent_in=0.0
	animal.activity="rest"
	animal.gait_rate=0.0
	animal.last_goal=animal.p
	animal.goals_chosen=0
	animal.activity_changes=0

func _idle_duration(animal:Dictionary) -> float:
	var interval:Vector2=Data.info(str(animal.species)).ecology.idle
	return rng.randf_range(interval.x,interval.y)*float(animal.temperament.patience)

func _rest(animal:Dictionary) -> void:
	_set_state(animal,"idle",_idle_duration(animal))
	# The body stays still; a few guarded head/body turns suggest listening,
	# sniffing and grazing without playing walking frames in place.
	animal.activity="graze" if animal.species in ["rabbit","deer"] and rng.randf()<0.62 else "look"
	animal.look_in=rng.randf_range(0.8,2.3)
	animal.activity_changes=int(animal.activity_changes)+1

func _new_wander_goal(game:Variant,animal:Dictionary) -> Vector2:
	_initialize_traits(animal)
	var spec:Dictionary=Data.info(str(animal.species))
	var leg:Vector2=spec.ecology.leg
	var previous:Vector2=animal.get("last_goal",animal.p)
	if animal.get("camp_visit",false) and animal.home.distance_to(Data.CAMP)<800:
		if animal.p.distance_to(Data.CAMP)<140:animal.camp_visit=false
		else:
			for attempt in range(20):
				var visit:Vector2=Data.CAMP+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(88,125)
				if visit.distance_to(animal.home)<650 and _walkable(game,animal,visit) and _reachable(game,animal.p,visit):
					animal.last_goal=visit;animal.goals_chosen=int(animal.goals_chosen)+1
					return visit
	if spec.predator and not animal.get("shadow",false) and game.get("beacon")!=null and game.beacon.igniting() and animal.home.distance_to(game.beacon.BEACON_POS)<1100 and rng.randf()<0.7:
		for attempt in range(12):
			var goal:Vector2=game.beacon.BEACON_POS+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(150,240)
			if _walkable(game,animal,goal) and _reachable(game,animal.p,goal):
				animal.last_goal=goal;animal.goals_chosen=int(animal.goals_chosen)+1
				return goal
	var hunt_chance: float = night_hunt_chance(game)
	if animal.species == "bear" and game.has_method("night_mod") and bool(game.night_mod("bear_hunts", false)): hunt_chance = 0.9
	if spec.predator and not animal.get("shadow",false) and period=="night" and rng.randf()<hunt_chance:
		var trail:Vector2=scent_point(10.0,28.0)
		if trail!=Vector2.INF:
			for attempt in range(8):
				var goal:Vector2=trail+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(0.0,70.0)
				if _walkable(game,animal,goal) and _reachable(game,animal.p,goal):
					animal.hunting=true;animal.activity="track"
					animal.last_goal=goal;animal.goals_chosen=int(animal.goals_chosen)+1
					return goal
	# A lit torch is visible from far away at night: curious predators come to
	# look, though the light then makes them hesitate (see predator_behavior).
	if spec.predator and not animal.get("shadow",false) and period=="night" and bool(game.torch_lit) and animal.p.distance_to(game.player)<560.0 and rng.randf()<0.6:
		var near_light:Vector2=game.player+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(120.0,200.0)
		if _walkable(game,animal,near_light) and _reachable(game,animal.p,near_light):
			animal.hunting=true;animal.activity="track"
			animal.last_goal=near_light;animal.goals_chosen=int(animal.goals_chosen)+1
			return near_light
	# The known lantern is a landmark for nearby predators, not knowledge of
	# the player's hidden position. Later nights bring more curious approaches.
	if spec.predator and not animal.get("shadow",false) and animal.home.distance_to(Data.CAMP)<800 and rng.randf()<[0.12,0.28,0.44][clampi(game.night-1,0,2)]:
		for attempt in range(10):
			var goal:Vector2=Data.CAMP+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(140,230)
			if goal.distance_to(animal.home)<float(animal.temperament.roam) and _walkable(game,animal,goal) and _reachable(game,animal.p,goal):
				animal.last_goal=goal;animal.goals_chosen=int(animal.goals_chosen)+1
				return goal
	for attempt in range(32):
		var angle:float=rng.randf()*TAU
		var goal:Vector2=animal.p+Vector2(cos(angle),sin(angle))*rng.randf_range(leg.x,leg.y)
		# Occasionally visit another part of this animal's actual painted habitat.
		# A bounded territory and legal navigation keep randomness ecological.
		if attempt%4==3:
			var habitat:Rect2=spec.habitats[rng.randi_range(0,spec.habitats.size()-1)]
			goal=habitat.position+Vector2(rng.randf(),rng.randf())*habitat.size
		if goal.distance_to(animal.home)>float(animal.temperament.roam):continue
		if goal.distance_to(animal.p)<45.0 or goal.distance_to(previous)<35.0:continue
		if not _walkable(game,animal,goal):continue
		if not _reachable(game,animal.p,goal):continue
		animal.last_goal=goal
		animal.goals_chosen=int(animal.goals_chosen)+1
		return goal
	return animal.p

func _reachable(game:Variant,start:Vector2,finish:Vector2) -> bool:
	if _line_clear(game,start,finish):return true
	if game.nav_grid == null:return false
	var from:Vector2i=game.nav_cell(start)
	var to:Vector2i=game.nav_cell(finish)
	return from.x>=0 and to.x>=0 and not game.nav_grid.get_id_path(from,to).is_empty()

func _escape_goal(game:Variant,animal:Dictionary,threat:Vector2) -> Vector2:
	var away:Vector2=(animal.p-threat).normalized()
	if away.length_squared()<0.1:away=Vector2.RIGHT.rotated(rng.randf()*TAU)
	var reach:float=float(Data.info(str(animal.species)).ecology.escape)
	# Try a consistent preferred side before the opposite side when a trunk or
	# pond blocks the direct escape. Goal selection is deliberately infrequent.
	for attempt in range(14):
		var spread:float=0.0 if attempt==0 else float(ceili(attempt/2.0))*0.22
		var sign_side:float=float(animal.temperament.flight_side)*(1.0 if attempt%2==1 else -1.0)
		var goal:Vector2=animal.p+away.rotated(spread*sign_side)*reach*rng.randf_range(0.8,1.15)
		if goal.distance_to(threat)<animal.p.distance_to(threat)+45.0:continue
		if _walkable(game,animal,goal) and _reachable(game,animal.p,goal):return goal
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
	_initialize_traits(animal)
	var spec:Dictionary=Data.info(str(animal.species))
	animal.moving=false
	animal.gait_rate=0.0
	animal.age+=dt
	animal.hitflash=maxf(0.0,float(animal.hitflash)-dt)
	animal.hurt_grace=maxf(0.0,float(animal.hurt_grace)-dt)
	animal.timer=maxf(0.0,float(animal.timer)-dt)
	animal.awareness=maxf(0.0,float(animal.awareness)-dt)
	animal.decision=maxf(0.0,float(animal.decision)-dt)
	animal.look_in=maxf(0.0,float(animal.look_in)-dt)
	animal.scent_in=maxf(0.0,float(animal.get("scent_in",0.0))-dt)
	animal.repath-=dt
	var distance:float=animal.p.distance_to(game.player)
	if spec.predator:
		Predator.update(self,game,animal,dt)
		return
	var notice:float=float(spec.notice)*float(animal.temperament.notice)
	var clear_sight:bool=distance<notice and _line_clear(game,animal.p,game.player)
	if clear_sight:
		animal.last_seen=game.player
		animal.awareness=float(animal.temperament.memory)
	if not spec.predator:
		if clear_sight:
			var entering:bool=animal.state!="flee"
			if entering:
				_set_state(animal,"flee")
				if animal.species=="deer":_alarm_herd(game,animal)
			animal.timer=float(animal.temperament.memory)
			animal.activity="escape"
			if entering or float(animal.decision)<=0.0 or animal.p.distance_to(animal.goal)<18.0:
				animal.goal=_escape_goal(game,animal,game.player)
				animal.decision=rng.randf_range(0.65,1.15)
				animal.repath=0.0
		elif animal.state=="flee":
			if float(animal.timer)<=0.0 or distance>notice*1.9:
				_rest(animal)
			elif animal.p.distance_to(animal.goal)<18.0:
				animal.goal=_escape_goal(game,animal,animal.last_seen)
				animal.decision=rng.randf_range(0.8,1.3)
				animal.repath=0.0
	if animal.state=="idle":
		_idle_look(game,animal)
		if float(animal.timer)>0.0:return
		_set_state(animal,"wander")
		animal.activity="roam"
		animal.goal=_new_wander_goal(game,animal)
	if animal.state=="return" and animal.p.distance_to(animal.home)<30.0:
		_rest(animal);return
	if animal.state=="wander" and animal.p.distance_to(animal.goal)<12.0:
		_rest(animal);return
	var speed:float=float(spec.speed)*float(animal.temperament.pace)
	if animal.state=="flee":speed=float(spec.flee_speed)*minf(1.05,float(animal.temperament.pace))
	elif animal.state=="chase":speed=float(spec.chase_speed)*minf(1.02,float(animal.temperament.pace))
	elif animal.state=="investigate":speed=float(spec.chase_speed)*0.80*minf(1.02,float(animal.temperament.pace))
	_move_toward(game,animal,animal.goal,speed,dt)

func _alarm_herd(game:Variant,source:Dictionary) -> void:
	for other in animals:
		if other==source or other.species!="deer" or other.state=="flee":continue
		if other.p.distance_to(source.p)>240.0:continue
		_initialize_traits(other)
		_set_state(other,"flee");other.timer=float(other.temperament.memory);other.activity="escape"
		other.last_seen=game.player
		other.goal=_escape_goal(game,other,game.player);other.decision=rng.randf_range(0.65,1.15);other.repath=0.0

func _idle_look(game:Variant,animal:Dictionary) -> void:
	if float(animal.look_in)>0.0:return
	animal.look_in=rng.randf_range(0.9,2.7)
	var angle:float=atan2(animal.facing.x,animal.facing.y)+rng.randf_range(-0.75,0.75)
	_try_facing(game,animal,Vector2(sin(angle),cos(angle)))

func _replan(game:Variant,animal:Dictionary,goal:Vector2) -> void:
	animal.repath = 0.75+rng.randf()*0.35
	animal.nav_revision = int(game.nav_revision)
	if _travel_clear(game,animal,animal.p,goal):
		animal.path = PackedVector2Array([goal]);animal.cursor=0;return
	var grid:AStarGrid2D=_species_navigation(game,str(animal.species))
	var from:Vector2i = _species_cell(grid,animal.p)
	var to:Vector2i = _species_cell(grid,goal)
	animal.path = grid.get_point_path(from,to) if from.x >= 0 and to.x >= 0 else PackedVector2Array()
	animal.cursor = 0

func _move_toward(game:Variant,animal:Dictionary,goal:Vector2,speed:float,dt:float) -> void:
	if float(animal.repath) <= 0.0 or int(animal.nav_revision) != int(game.nav_revision):_replan(game,animal,goal)
	var path:PackedVector2Array = animal.path
	while int(animal.cursor) < path.size() and animal.p.distance_to(path[int(animal.cursor)]) < 4.0:animal.cursor += 1
	if int(animal.cursor) >= path.size():
		animal.repath = minf(float(animal.repath),0.15)
		animal.stuck += dt
		if float(animal.stuck) > 1.2 and animal.state in ["wander","return"]:
			_rest(animal)
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
		animal.gait_rate=walked/maxf(dt,0.0001)
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
				animal.goal = _escape_goal(game,animal,animal.last_seen)
				animal.decision=rng.randf_range(0.65,1.1)
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
		best = {"uid":int(animal.uid),"species":str(animal.species),"shadow":bool(animal.get("shadow",false)),"pos":animal.p,"kind":"wildlife"}
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
			if not animal.get("shadow",false): kills[animal.species] = int(kills.get(animal.species,0))+1
		else:
			# A landed blow interrupts an attack; recovery prevents an immediate bite.
			if bool(Data.info(str(animal.species)).predator):_set_state(animal,"recover",0.75)
			else:
				_set_state(animal,"flee",2.0)
				animal.goal = _escape_goal(game,animal,origin)
				animal.last_seen=origin
				animal.decision=rng.randf_range(0.65,1.1)
	animals = animals.filter(func(animal):return float(animal.hp)>0.0)
	return {"hits":hit_ids.size(),"hit_ids":hit_ids,"kills":killed}

func respawn_delay(game: Variant) -> float:
	return float(Balance.night_profile(game.night).respawn) if period == "night" else Data.RESPAWN_DELAY

func has_shadow() -> bool:
	for animal in animals:
		if animal.get("shadow",false): return true
	return false

func dismiss_shadow() -> void:
	if not has_shadow(): return
	animals = animals.filter(func(a): return not a.get("shadow",false))

func spawn_shadow(game: Variant) -> bool:
	var shadow_at: float = float(game.night_mod("shadow_threshold", 30.0)) if game.has_method("night_mod") else 30.0
	# v0.3.0: deep in the Fallen Ruins shadows also walk by day.
	var daylight: bool = game.get("region_world") != null and game.region_world.daylight_shadows(game)
	if daylight: shadow_at = maxf(shadow_at, float(game.region_world.DEEP_SHADOW_SANITY))
	if has_shadow() or (game.phase != "night" and not daylight) or game.sanity >= shadow_at or game.survival.light_at(game,game.player) >= 0.45: return false
	# Shadows are not ordinary habitat wildlife. Choose a bounded local ring,
	# far enough to react, with the SAME wolf footprints and connected planner.
	for attempt in range(80):
		var p:Vector2=game.player+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(360,520)
		var facing:Vector2=(game.player-p).normalized()
		var candidate:Dictionary={"uid":next_uid,"species":"wolf","facing":facing}
		if not _walkable(game,candidate,p,true) or game.survival.light_at(game,p)>=0.20:continue
		if not _reachable(game,p,game.player):continue
		var grid:AStarGrid2D=_species_navigation(game,"wolf")
		var a_cell:Vector2i=_species_cell(grid,p)
		var b_cell:Vector2i=_species_cell(grid,game.player)
		if a_cell.x<0 or b_cell.x<0 or grid.get_id_path(a_cell,b_cell).is_empty():continue
		var a:Dictionary=_register_animal(game,"wolf",p,facing)
		a.shadow=true;a.hp=42.0;a.state="investigate";a.last_seen=game.player
		a.goal=game.player;a.awareness=8.0;a.timer=8.0
		return true
	return false
