extends SceneTree
const Roaming=preload("res://npc_roaming.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures.append(label)
		if failures.size()<20:push_error("FAIL "+label)
func _run()->void:
	var game:Variant=load("res://main.tscn").instantiate()
	game.resource_seed=157;root.add_child(game);game.set_process(false)
	await process_frame
	game.wildlife.animals.clear()
	var roaming:=Roaming.new();roaming.setup(game,6161)
	var distances:Dictionary={"Rowan":0.0,"Ash":0.0}
	var cells:Dictionary={"Rowan":{},"Ash":{}}
	game.phase="day"
	for tick in range(1400):
		var previous:Dictionary={}
		for name in game.npc_states:previous[name]=game.npc_states[name].p
		roaming.update(game,.05)
		for name in game.npc_states:
			var npc:Dictionary=game.npc_states[name]
			var moved:float=npc.p.distance_to(previous[name]);distances[name]+=moved
			check(moved<3.2,"actual map "+name+" never teleports")
			if tick%5==0:
				check(game.static_walkable(npc.p),"actual map "+name+" feet avoid all authored ground footprints")
				check(not Geometry.polygons_overlap(game.feet_polygon(npc.p),game.feet_polygon(game.player)),"actual map "+name+" avoids player feet")
			cells[name][Vector2i(npc.p/Vector2(40,40))]=true
	for name in game.npc_states:
		check(distances[name]>200.0,"actual map "+name+" accumulates real walking distance")
		check(cells[name].size()>5,"actual map "+name+" visits diverse locations")
		check(int(game.npc_states[name].goals_chosen)>3,"actual map "+name+" has multiple random activity legs")
	game.phase="dusk"
	for tick in range(1000):
		roaming.update(game,.05)
		if tick%10==0:
			for name in game.npc_states:check(game.static_walkable(game.npc_states[name].p),"night shelter route stays on legal ground")
	for name in game.npc_states:
		check(game.npc_states[name].p.distance_to(Vector2(455,725))<160.0,"actual map "+name+" arrives in protected night camp")
	print("NPC_WORLD_RESULT checks=",checks," failures=",failures.size()," walked=",distances," cells=",cells.Rowan.size(),"/",cells.Ash.size()," final=",game.npc_states.Rowan.p,"/",game.npc_states.Ash.p)
	game.queue_free();quit(0 if failures.is_empty() else 1)
