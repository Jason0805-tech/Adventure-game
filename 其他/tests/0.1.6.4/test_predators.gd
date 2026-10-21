extends SceneTree
const Wildlife=preload("res://wildlife.gd")
const Balance=preload("res://survival_balance.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]
class World extends Node2D:
	var player:=Vector2(1400,700)
	var npc_states:Dictionary={}
	var solid_bodies:Array[Dictionary]=[]
	var nav_grid:=AStarGrid2D.new()
	var nav_revision:=0
	var health:=100.0
	var phase:="night"
	var night:=1
	var sanity:=100.0
	var fullness:=100
	var torch_lit:=false
	var torch_fuel:=120.0
	var survival=preload("res://sanity_system.gd").new()
	var wildlife:Variant
	var hits:=0
	func _init()->void:
		nav_grid.region=Rect2i(0,0,184,125);nav_grid.cell_size=Vector2(12,12);nav_grid.offset=Vector2(6,6);nav_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav_grid.update()
	func feet_polygon(p:Vector2)->PackedVector2Array:return Geometry.capsule_polygon(p+Vector2(0,-1),14,7,8)
	func body_active(_body:Dictionary)->bool:return true
	func nav_cell(p:Vector2)->Vector2i:return Vector2i(int(p.x/12),int(p.y/12))
	func wildlife_damage(amount:float,_species:String)->float:health-=amount;hits+=1;return amount
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func one(g:Variant,species:String,p:Vector2)->Dictionary:
	g.wildlife.animals.clear();g.wildlife._spawn_one(g,species)
	var a:Dictionary=g.wildlife.animals[0];a.p=p;a.home=p;a.facing=Vector2.RIGHT;a.age=20.0;a.timer=1.0
	a.temperament.pace=1.0;a.temperament.notice=1.0
	return a
func step(g:Variant,a:Dictionary,seconds:float)->void:
	for i in range(roundi(seconds*20)):
		g.wildlife.player_hit_grace=maxf(0,g.wildlife.player_hit_grace-.05)
		g.wildlife._update_animal(g,a,.05)
func run()->void:
	var g:=World.new();root.add_child(g);g.wildlife=Wildlife.new();g.wildlife.setup(g,164)
	for n in [1,2,3]:
		g.night=n;g.player=Vector2(1400,700);g.torch_lit=false
		var a:Dictionary=one(g,"wolf",Vector2(1290,700));var p:Vector2=a.p
		step(g,a,.05)
		check(a.state=="chase" and absf(a.p.distance_to(p)/.05-float(Balance.night_profile(n).wolf_speed))<.01,"wolf exact pursuit speed night"+str(n))
		check(a.p.distance_to(p)/.05>108,"wolf faster than normal player night"+str(n))
		var walk_before:float=a.walk
		check(walk_before>0 and a.gait_rate>108,"continuous distance-driven wolf gait night"+str(n))
		g.torch_lit=true;a.courage=10.0;a.pursuit=0;a.state="chase";p=a.p
		step(g,a,.05)
		check(a.p.distance_to(p)/.05<108,"torch offers real running escape night"+str(n))
		g.torch_lit=false;a.state="chase";a.pursuit=float(Balance.night_profile(n).pursuit)-.01
		step(g,a,.05);check(a.state=="exhausted" and not a.moving and a.timer>=4.4,"bounded wolf chase and recovery night"+str(n))
		# Warning locks aim; a stationary unprepared player takes one hit only.
		a=one(g,"wolf",Vector2(1360,700));g.health=100;g.hits=0;g.wildlife.player_hit_grace=0
		step(g,a,.05);check(a.state=="windup" and g.hits==0,"wolf warns before biting night"+str(n))
		step(g,a,.75);check(g.hits==1 and g.health==88 and a.state=="recover","one bite damage, recovery night"+str(n))
		step(g,a,.40);check(g.hits==1,"no repeated damage during recovery night"+str(n))
		# Reset, sidestep after warning. Same real feet and attack arc.
		a=one(g,"wolf",Vector2(1360,700));g.hits=0;g.health=100;g.wildlife.player_hit_grace=0
		step(g,a,.05);g.player+=Vector2(0,90);step(g,a,.75)
		check(g.hits==0,"wolf bite avoidable by sidestep night"+str(n))
		# Bears charge only after a visible, locked one-second warning.
		g.player=Vector2(1450,700);var bear:Dictionary=one(g,"bear",Vector2(1300,700));bear.charge_cooldown=0;g.hits=0
		step(g,bear,.05);check(bear.state=="charge_warn" and not bear.moving,"bear charge prewarning night"+str(n))
		var entry:Dictionary=g.wildlife.entries()[0]
		check(entry.warning and entry.state=="charge_warn","charge warning exposed to existing overlay night"+str(n))
		step(g,bear,.9);check(bear.state=="charge_warn" and g.hits==0,"no premature bear movement or damage night"+str(n))
		g.player.y+=100;step(g,bear,.2);var before:Vector2=bear.p
		step(g,bear,.2)
		check(bear.p.x>before.x and absf(bear.p.y-700)<.1,"bear charge fixed heading, not homing night"+str(n))
		step(g,bear,.6);check(g.hits==0 and bear.state=="recover" and bear.charge_cooldown>6,"bear dodge and charge cooldown night"+str(n))
		# Charge into a solid must stop rather than pass through.
		g.player=Vector2(1450,700);bear=one(g,"bear",Vector2(1300,700));bear.charge_cooldown=0;step(g,bear,.05);step(g,bear,1.0)
		g.solid_bodies=[{"polygon":PackedVector2Array([Vector2(1360,600),Vector2(1370,600),Vector2(1370,800),Vector2(1360,800)]),"bounds":Rect2(1360,600,10,200)}];g.nav_revision+=1
		step(g,bear,.8)
		check(bear.p.x<1360 and g.wildlife._ground_clear(g,bear,bear.p),"bear charge respects exact obstacle night"+str(n));g.solid_bodies.clear();g.nav_revision+=1
	# Light is not an invincible circle: feet and attacks are legal in camp.
	g.night=3;g.player=Vector2(455,725);g.torch_lit=false
	var wolf:Dictionary=one(g,"wolf",Vector2(415,725));g.health=100;g.hits=0;g.wildlife.player_hit_grace=0
	check(g.wildlife._walkable(g,wolf,Vector2(405,725)),"no artificial160-unit camp collision wall")
	check(g.wildlife._travel_clear(g,wolf,Vector2(300,725),Vector2(400,725)),"navigation may enter lit camp")
	step(g,wolf,3.0);check(g.hits>=1 and g.health<100,"camp can be attacked after light hesitation")
	# Walls break pursuit, with bounded last-seen investigation, not omniscient scent.
	g.player=Vector2(1450,700);wolf=one(g,"wolf",Vector2(1300,700));step(g,wolf,.05)
	g.solid_bodies=[{"polygon":PackedVector2Array([Vector2(1360,600),Vector2(1370,600),Vector2(1370,800),Vector2(1360,800)]),"bounds":Rect2(1360,600,10,200)}];g.nav_revision+=1
	step(g,wolf,.05);check(wolf.state=="investigate","wolf loses direct chase behind obstacle")
	g.player=Vector2(1950,950);step(g,wolf,4.0);check(wolf.state in ["idle","wander"],"wolf abandons bounded lost-sight memory");g.solid_bodies.clear();g.nav_revision+=1
	for species in ["rabbit","deer","fox"]:
		g.player=Vector2(1400,700);var passive:Dictionary=one(g,species,Vector2(1520,700));step(g,passive,.5)
		check(passive.state=="flee" and passive.p.distance_to(g.player)>120,"passive ecology preserved "+species)
	# Real combat interrupts all telegraphs and charges, obeys direction/LOS/grace.
	g.player=Vector2(1400,700);wolf=one(g,"wolf",Vector2(1450,700));wolf.state="windup";wolf.timer=.5
	var result:Dictionary=g.wildlife.attack(g,g.player,Vector2.RIGHT,48,68,.2)
	check(result.hits==1 and wolf.hp==17 and wolf.state=="recover","advanced blade interrupts attack and deals48")
	check(g.wildlife.attack(g,g.player,Vector2.RIGHT,48,68,.2).hits==0,"contact hurt grace prevents duplicate hit")
	wolf.hurt_grace=0;check(g.wildlife.attack(g,g.player,Vector2.LEFT,48,68,.2).hits==0,"rear target cannot be hit")
	check(g.wildlife.attack(g,g.player,Vector2.RIGHT,48,68,.2).kills.size()==1,"weapon can defeat real predator")
	for n in [1,2,3]:
		g.night=n;g.wildlife.setup(g,164+n);g.wildlife.update(g,0,"night")
		var wolves:=0
		for a in g.wildlife.animals:
			if a.species=="wolf":wolves+=1
			check(a.p.distance_to(g.player)>=360,"predators never spawn beside player night"+str(n))
		check(wolves==int(Balance.night_profile(n).wolves) and g.wildlife.animals.size()<=4,"night cap increases without excessive enemies"+str(n))
	check(Balance.night_profile(1).notice<Balance.night_profile(2).notice and Balance.night_profile(2).notice<Balance.night_profile(3).notice,"night pressure increases in perception, not just counts")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open(ProjectSettings.globalize_path("res://../predator-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PREDATOR_RESULTS ",JSON.stringify(report));g.queue_free();quit(0 if failures.is_empty() else 1)
