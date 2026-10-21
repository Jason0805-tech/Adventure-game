extends SceneTree
const Wildlife=preload("res://wildlife.gd")
const Balance=preload("res://survival_balance.gd")
const Geometry=preload("res://world_geometry.gd")
var failures:Array[String]=[]
var rows:Array[Dictionary]=[]
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
	func _init()->void:
		nav_grid.region=Rect2i(0,0,184,125);nav_grid.cell_size=Vector2(12,12);nav_grid.offset=Vector2(6,6);nav_grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;nav_grid.update()
	func feet_polygon(p:Vector2)->PackedVector2Array:return Geometry.capsule_polygon(p+Vector2(0,-1),14,7,8)
	func body_active(_body:Dictionary)->bool:return true
	func nav_cell(p:Vector2)->Vector2i:return Vector2i(int(p.x/12),int(p.y/12))
	func wildlife_damage(amount:float,_species:String)->float:health-=amount;return amount
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label);push_error("FAIL "+label)
func run()->void:
	var g:=World.new();root.add_child(g);g.wildlife=Wildlife.new()
	for n in [1,2,3]:
		g.night=n;g.phase="night";g.player=Vector2(1400,700);g.wildlife.setup(g,9000+n);g.wildlife.update(g,0,"night")
		var wolves:=0;var bears:=0;var seen_wolf:=false;var seen_bear:=false;var clear_locations:=true
		for a in g.wildlife.animals:
			if a.species=="wolf":wolves+=1
			if a.species=="bear":bears+=1
			if a.species in ["wolf","bear"] and a.p.distance_to(g.player)<360:clear_locations=false
		for entry in g.wildlife.entries():
			if entry.species=="wolf":seen_wolf=true
			if entry.species=="bear":seen_bear=true
		var expected:=int(Balance.night_profile(n).wolves)
		check(wolves==expected,"night %d spawned %d/%d wolves"%[n,wolves,expected])
		check(bears==1,"night %d spawned one bear"%n)
		check(clear_locations,"night %d predators spawn outside 360-unit grace radius"%n)
		check(seen_wolf and seen_bear,"night %d exposes wolf and bear render entries"%n)
		for i in range(8):g.wildlife.update(g,.1,"night")
		var visible:=true
		for entry in g.wildlife.entries():
			if entry.species in ["wolf","bear"] and float(entry.alpha)<.99:visible=false
		check(visible,"night %d wildlife entries finish spawn fade"%n)
		rows.append({"night":n,"wolves":wolves,"expected_wolves":expected,"bears":bears,"predator_min_distance":360,"wolf_and_bear_entries":seen_wolf and seen_bear,"fade_complete":visible})
		g.wildlife.update(g,0,"day")
		var predators_left:=0
		for a in g.wildlife.animals:
			if a.species in ["wolf","bear"]:predators_left+=1
		check(predators_left==0,"predators despawn on day transition after night %d"%n)
	var report:Dictionary={"night_runs":rows,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.4/itchio-package/night-spawn-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ITCHIO_NIGHT_SPAWNS ",JSON.stringify(report));g.queue_free();quit(0 if failures.is_empty() else 1)
