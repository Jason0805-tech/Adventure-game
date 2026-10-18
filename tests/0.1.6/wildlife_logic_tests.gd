extends SceneTree
const Wildlife = preload("res://wildlife.gd")
const WildlifeData = preload("res://wildlife_data.gd")
const Geometry = preload("res://world_geometry.gd")
var checks := 0
var failures:Array[String] = []

class Sandbox extends Node:
	var player := Vector2(360,760)
	var npc_states:Dictionary = {"Rowan":{"p":Vector2(455,725)},"Ash":{"p":Vector2(1280,970)}}
	var solid_bodies:Array[Dictionary] = []
	var nav_grid := AStarGrid2D.new()
	var nav_revision := 0
	var health := 100.0
	func _init() -> void:
		nav_grid.region=Rect2i(0,0,184,125)
		nav_grid.cell_size=Vector2(12,12)
		nav_grid.offset=Vector2(6,6)
		nav_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		nav_grid.update()
	func feet_polygon(at:Vector2) -> PackedVector2Array:
		return Geometry.capsule_polygon(at+Vector2(0,-1),14,7,8)
	func body_active(_body:Dictionary) -> bool:return true
	func nav_cell(at:Vector2) -> Vector2i:
		var id := Vector2i(int(at.x/12),int(at.y/12))
		return id if nav_grid.region.has_point(id) and not nav_grid.is_point_solid(id) else Vector2i(-1,-1)
	func take_damage(amount:float) -> void:health=maxf(0,health-amount)
	func add_wall(rect:Rect2) -> void:
		var polygon := PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
		solid_bodies.append({"polygon":polygon,"bounds":rect})
		for y in range(nav_grid.region.size.y):
			for x in range(nav_grid.region.size.x):
				var id:=Vector2i(x,y)
				if Geometry.polygons_overlap(feet_polygon(nav_grid.get_point_position(id)),polygon):nav_grid.set_point_solid(id,true)
		nav_revision+=1

func _initialize() -> void:call_deferred("_run")

func check(condition:bool,label:String) -> void:
	checks+=1
	if not condition:
		failures.append(label)
		push_error("FAIL "+label)

func counts(sim:Variant) -> Dictionary:
	var out:Dictionary = {}
	for animal in sim.animals:out[animal.species]=int(out.get(animal.species,0))+1
	return out

func one(sim:Variant,game:Variant,species:String,at:Vector2) -> Dictionary:
	sim.animals.clear()
	sim._spawn_one(game,species)
	var animal:Dictionary = sim.animals[0]
	animal.p=at;animal.home=at;animal.age=5.0
	animal.facing=Vector2.DOWN
	animal.state="idle";animal.timer=2.0
	return animal

func _run() -> void:
	var game := Sandbox.new()
	root.add_child(game)
	var sim := Wildlife.new()
	sim.setup(game,516)
	sim.update(game,0.016,"day")
	check(counts(sim)=={"rabbit":4,"deer":3,"fox":2},"day has exactly four rabbits three deer two foxes")
	var initial:Array = sim.animals.map(func(a):return a.p)
	var other := Wildlife.new()
	other.setup(game,516);other.update(game,0.016,"day")
	check(initial==other.animals.map(func(a):return a.p),"fixed seed reproduces placements and update")
	for animal in sim.animals:
		check(animal.p.distance_to(game.player)>=170,"day spawn away from player")
		check(animal.p.distance_to(WildlifeData.CAMP)>=160,"all species spawn outside camp")
		check(sim._ground_clear(game,animal,animal.p),"spawn uses actual species ground capsule")
		check(not sim._walkable(game,animal,WildlifeData.CAMP),"camp is unavailable to animal feet")
	var snapshot:Array = sim.animals.duplicate(true)
	var old_respawn:float = sim.respawn_in
	sim.update(game,50.0,"day",false)
	check(sim.animals==snapshot and sim.respawn_in==old_respawn,"paused update changes no positions timer or phase")
	sim.update(game,0.0,"dusk",false)
	check(counts(sim)=={"fox":2},"rabbits and deer leave immediately at dusk")
	sim.update(game,0.0,"night")
	check(counts(sim)=={"wolf":3,"bear":1},"night has only three wolves and one bear")
	for animal in sim.animals:check(animal.p.distance_to(game.player)>=360,"predator spawn starts beyond 360 units")
	for index in range(900):sim.update(game,0.05,"night")
	check(counts(sim)=={"wolf":3,"bear":1},"long night remains within species caps")
	for animal in sim.animals:
		check(sim._ground_clear(game,animal,animal.p),"night wander remains inside legal map")
		check(animal.p.distance_to(WildlifeData.CAMP)>=160,"night wander cannot enter camp")
		check(int(sim.entries()[0].frame)>=0 and int(sim.entries()[0].frame)<=8,"render frame remains in nine-row atlas")
	sim.update(game,0.016,"day")
	check(counts(sim)=={"rabbit":4,"deer":3,"fox":2},"sunrise removes predators and restores day ecology")
	# A short object blocks ground feet; no artificial full sprite silhouette exists.
	game.add_wall(Rect2(980,680,40,40))
	var bear:Dictionary=one(sim,game,"bear",Vector2(1050,700))
	check(not sim._ground_clear(game,bear,Vector2(1040,700)),"wide bear cannot clip a stone edge")
	var rabbit:Dictionary={"species":"rabbit","uid":999}
	check(sim._ground_clear(game,rabbit,Vector2(1040,700)),"small rabbit has its own footprint rather than bear/player size")
	check(sim.body_blocked(Vector2(1050,700)),"animal ground feet block approaching player")
	var big_candidate:=PackedVector2Array([Vector2(1030,670),Vector2(1300,670),Vector2(1300,740),Vector2(1030,740)])
	check(sim.body_blocked(Vector2(1300,700),-1,big_candidate),"large workbench candidate uses polygon overlap without center shortcut")
	check(not sim.body_blocked(Vector2(1050,700),int(bear.uid)),"animal can exclude its own collider")
	# Locked-aim attacks: no instant damage; standing still takes one hit.
	game.solid_bodies.clear();game.health=100
	var wolf:Dictionary=one(sim,game,"wolf",Vector2(1400,700))
	game.player=Vector2(1435,700)
	sim.period="night";sim.player_hit_grace=0.0
	sim.update(game,.05,"night")
	check(wolf.state=="windup" and game.health==100,"wolf telegraphs before damage")
	for index in range(12):sim.update(game,.05,"night")
	check(game.health==100,"wolf cannot damage before full windup")
	for index in range(2):sim.update(game,.05,"night")
	check(game.health==88 and wolf.state=="recover","one stationary bite enters recovery")
	for index in range(18):sim.update(game,.05,"night")
	check(game.health==88,"recovery prevents repeated contact damage")
	# Evade by moving during the windup.
	wolf=one(sim,game,"wolf",Vector2(1400,700));game.player=Vector2(1435,700);game.health=100
	sim.player_hit_grace=0
	sim.update(game,.05,"night");game.player=Vector2(1435,780)
	for index in range(16):sim.update(game,.05,"night")
	check(game.health==100,"moving beyond attack range during telegraph avoids bite")
	# Global hurt grace means a pack cannot apply same-frame stacked damage.
	wolf=one(sim,game,"wolf",Vector2(1400,700));game.player=Vector2(1435,700);game.health=100
	var second:Dictionary=wolf.duplicate(true);second.uid=999;second.p=Vector2(1440,720);sim.animals.append(second)
	sim.player_hit_grace=0
	for index in range(16):sim.update(game,.05,"night")
	check(game.health==88,"shared player hurt grace prevents simultaneous pack hits")
	# Swing cone, interruptions, wall occlusion and health removal.
	wolf=one(sim,game,"wolf",Vector2(1435,700));game.player=Vector2(1400,700)
	wolf.state="windup";wolf.timer=.5;wolf.locked_aim=game.player
	var result:Dictionary=sim.attack(game,game.player,Vector2.LEFT,30,64)
	check(int(result.hits)==0 and float(wolf.hp)==65,"weapon does not hit behind player")
	result=sim.attack(game,game.player,Vector2.RIGHT,30,64)
	check(int(result.hits)==1 and wolf.state=="recover" and float(wolf.hp)==35,"front swing damages and interrupts windup")
	check(int(sim.attack(game,game.player,Vector2.RIGHT,100,64).hits)==0,"one swing cannot hit same animal repeatedly")
	wolf.hurt_grace=0
	game.add_wall(Rect2(1415,680,6,45))
	check(int(sim.attack(game,game.player,Vector2.RIGHT,100,64).hits)==0,"weapon cannot attack through a ground wall")
	game.solid_bodies.clear()
	result=sim.attack(game,game.player,Vector2.RIGHT,100,64)
	check(result.kills==["wolf"] and sim.animals.is_empty(),"defeated animal removed from rendering and collision")
	sim.period="night";sim.respawn_in=.02;game.player=Vector2(360,760)
	sim.update(game,.05,"night")
	check(counts(sim)=={"wolf":3,"bear":1},"timed respawn restores only currently active species")
	print("WILDLIFE_LOGIC_RESULT checks=",checks," failures=",failures.size())
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
