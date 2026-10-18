extends SceneTree
const Wildlife=preload("res://wildlife.gd")
const Data=preload("res://wildlife_data.gd")
const NpcRoaming=preload("res://npc_roaming.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]
class Sandbox extends Node:
	var player:=Vector2(360,760)
	var npc_states:Dictionary={"Rowan":{"p":Vector2(455,725),"facing":Vector2.DOWN,"walk":0.0,"speed":30.0},"Ash":{"p":Vector2(1280,970),"facing":Vector2.LEFT,"walk":0.0,"speed":43.0}}
	var npc_home:=Vector2(455,725)
	var npc_position:=Vector2(1280,970)
	var solid_bodies:Array[Dictionary]=[]
	var nav_grid:=AStarGrid2D.new()
	var nav_revision:=0
	var health:=100.0
	var phase:="day"
	var paused:=false
	var inventory:=false
	var crafting:=false
	var dialog:=""
	func _init()->void:
		nav_grid.region=Rect2i(0,0,184,125);nav_grid.cell_size=Vector2(12,12);nav_grid.offset=Vector2(6,6)
		nav_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav_grid.update()
	func feet_polygon(at:Vector2)->PackedVector2Array:return Geometry.capsule_polygon(at+Vector2(0,-1),14,7,8)
	func body_active(_body:Dictionary)->bool:return true
	func nav_cell(at:Vector2)->Vector2i:
		var id:=Vector2i(int(at.x/12),int(at.y/12))
		return id if nav_grid.region.has_point(id) and not nav_grid.is_point_solid(id) else Vector2i(-1,-1)
	func take_damage(amount:float)->void:health-=amount
	func npc_walkable(p:Vector2,name:String)->bool:
		if p.x<32 or p.y<40 or p.x>2168 or p.y>1468:return false
		if Geometry.polygons_overlap(feet_polygon(p),feet_polygon(player)):return false
		for other in npc_states:
			if other!=name and Geometry.polygons_overlap(feet_polygon(p),feet_polygon(npc_states[other].p)):return false
		return true
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func one(sim:Variant,game:Variant,species:String,p:Vector2)->Dictionary:
	sim.animals.clear();sim._spawn_one(game,species)
	var a:Dictionary=sim.animals[0]
	a.p=p;a.home=p;a.facing=Vector2.RIGHT;a.age=8.0;a.state="idle";a.timer=1.0
	return a
func _run()->void:
	var game:=Sandbox.new();root.add_child(game)
	var sim:=Wildlife.new();sim.setup(game,6161);sim.update(game,0.0,"day")
	var other:=Wildlife.new();other.setup(game,6162);other.update(game,0.0,"day")
	check(sim.animals.map(func(a):return a.p)!=other.animals.map(func(a):return a.p),"different seeds produce different population layouts")
	var paces:Dictionary={}
	for a in sim.animals:paces[float(a.temperament.pace)]=true
	check(paces.size()==sim.animals.size(),"individuals have distinct persistent pace")
	var deer:Dictionary=one(sim,game,"deer",Vector2(1600,1120))
	var quadrants:Dictionary={};var goals:Dictionary={};var furthest:=0.0
	for n in range(36):
		var goal:Vector2=sim._new_wander_goal(game,deer)
		goals[goal]=true;var relative:Vector2=goal-deer.p
		quadrants[Vector2(signf(relative.x),signf(relative.y))]=true
		furthest=maxf(furthest,relative.length())
		check(goal.distance_to(deer.home)<=float(deer.temperament.roam),"random destinations stay inside the individual territory")
	check(goals.size()>30 and quadrants.size()==4,"wander has many unique destinations in all quadrants")
	check(furthest>240.0,"deer explores beyond the old tiny repeated rectangle")
	var waits:Dictionary={}
	for n in range(20):waits[sim._idle_duration(deer)]=true
	check(waits.size()==20,"rest periods vary instead of one fixed patrol timing")
	for species in ["rabbit","deer","fox"]:
		game.player=Vector2(1330,700)
		var a:Dictionary=one(sim,game,species,Vector2(1400,700))
		var before:float=a.p.distance_to(game.player)
		sim._update_animal(game,a,0.05)
		check(a.state=="flee","passive "+species+" flees a nearby player")
		var escape_goal:Vector2=a.goal
		for n in range(8):
			game.player.y=700+sin(n)*2.0
			sim._update_animal(game,a,0.05)
		check(a.goal==escape_goal,"passive "+species+" holds one escape decision despite tiny player jitter")
		check(a.p.distance_to(game.player)>before+20.0,"passive "+species+" genuinely moves away")
		check(float(a.walk)>0.0 and float(a.gait_rate)>0.0,"passive "+species+" gait advances from actual distance")
	game.player=Vector2(1510,700)
	var wolf:Dictionary=one(sim,game,"wolf",Vector2(1400,700))
	sim._update_animal(game,wolf,.05)
	check(wolf.state=="chase" and wolf.p.x>1400,"predator approaches an observed nearby player")
	var last_seen:Vector2=wolf.last_seen
	game.solid_bodies.append({"polygon":PackedVector2Array([Vector2(1450,640),Vector2(1460,640),Vector2(1460,760),Vector2(1450,760)]),"bounds":Rect2(1450,640,10,120)})
	sim._update_animal(game,wolf,.05)
	check(wolf.state=="investigate" and wolf.last_seen==last_seen,"lost sight follows last observed position without snapping home")
	game.solid_bodies.clear();game.player=Data.CAMP
	sim._update_animal(game,wolf,.05)
	check(wolf.state in ["return","idle"] and float(wolf.awareness)==0.0,"camp safety clears pursuit memory")
	var moving_before:float=wolf.walk
	wolf.state="idle";wolf.timer=3.0
	sim._update_animal(game,wolf,.05)
	check(not wolf.moving and wolf.walk==moving_before,"planted rest does not play walking frames")
	var roaming:=NpcRoaming.new();roaming.setup(game,6161)
	for n in range(1400):roaming.update(game,0.05)
	for name in game.npc_states:
		var npc:Dictionary=game.npc_states[name]
		check(int(npc.goals_chosen)>5,name+" chooses multiple independent goals instead of a fixed loop")
		check(npc.p.distance_to(npc.home)<=float(npc.roam_radius)+5.0,name+" remains inside its daytime work territory")
	var npc_snapshot:Dictionary=game.npc_states.duplicate(true)
	game.paused=true;roaming.update(game,20)
	check(npc_snapshot==game.npc_states,"NPC complete state freezes while paused")
	game.paused=false;game.inventory=true;roaming.update(game,20)
	check(npc_snapshot==game.npc_states,"NPC complete state freezes inside backpack")
	game.inventory=false;game.phase="dusk"
	var ash_before:Vector2=game.npc_states.Ash.p
	roaming.update(game,.05)
	check(game.npc_states.Ash.p.distance_to(ash_before)<4.0,"night shelter transition moves normally without teleport")
	for n in range(700):roaming.update(game,.05)
	check(game.npc_states.Ash.p.distance_to(Data.CAMP)<160.0,"Ash walks all the way into the protected camp at night")
	game.phase="day"
	var ash_camp:Vector2=game.npc_states.Ash.p
	for n in range(100):roaming.update(game,.05)
	check(game.npc_states.Ash.p.distance_to(ash_camp)>70.0,"Ash leaves shelter and returns toward the woodland after dawn")
	print("ECOLOGY_BEHAVIOR_RESULT checks=",checks," failures=",failures.size())
	game.queue_free();quit(0 if failures.is_empty() else 1)
