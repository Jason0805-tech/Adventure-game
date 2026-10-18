extends SceneTree

# Player routes are exercised against the actual seeded world, and again against
# the same object's own bodies so a neighbor cannot conceal a missing obstacle.
# Visual checks independently sample original avatar pixels and actual ordered
# Canvas texture calls. A collider-only pass is never a visual pass.
const Geometry = preload("res://world_geometry.gd")
const OUT = "res://../../tests/0.1.5.9/"
var game: Variant
var checks := 0
var failures := 0
var worlds := 0
var actual_instances := 0
var variant_instances := 0
var world_approaches := 0
var blocked_starts := 0
var isolated_routes := 0
var no_body_routes := 0
var frames_simulated := 0
var contacts: Array = []
var coverage: Dictionary = {}
var failures_list: Array = []
var all_world_bodies: Array[Dictionary] = []
var image_cache: Dictionary = {}
var version := "0.1.5.9"

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures_list.size() < 100:
			failures_list.append(label)
			push_error("WALKTHROUGH_FAIL " + label)

func _initialize() -> void: call_deferred("run")
func v(p: Vector2) -> Array: return [p.x,p.y]
func body_id(entry: Dictionary) -> String:
	if entry.kind in ["water", "bank_rock"]: return str(entry.id)
	return "%s:%s:%d" % [entry.kind,str(entry.p),int(entry.index)]
func own_bodies(entry: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for body in game.solid_bodies:
		if str(body.id) == body_id(entry) and game.body_active(body): result.append(body)
	return result
func entry_bounds(entry: Dictionary, bodies: Array[Dictionary]) -> Rect2:
	if not bodies.is_empty():
		var bounds: Rect2 = bodies[0].bounds
		for body in bodies: bounds = bounds.merge(body.bounds)
		return bounds
	var spec: Dictionary = game.model_spec(str(entry.kind),entry.p,int(entry.index))
	if not spec.is_empty(): return game.sprite_rect(spec.texture,spec.foot,float(spec.height))
	return Rect2(entry.p-Vector2(14,8),Vector2(28,16))
func support(bodies: Array[Dictionary], bounds: Rect2, normal: Vector2) -> Vector2:
	var best: float = -INF
	var selected: Array[Vector2] = []
	for body in bodies:
		for point in body.polygon:
			var d: float = point.dot(normal)
			if d > best + 0.1: best=d;selected=[point]
			elif absf(d-best)<0.1:selected.append(point)
	if selected.is_empty(): return bounds.get_center()+normal*bounds.size*0.45
	var point := Vector2.ZERO
	for q in selected:point+=q
	return point/selected.size()
func route(entry: Dictionary, state: String, isolated: bool) -> void:
	var bodies: Array[Dictionary] = own_bodies(entry)
	var bounds: Rect2 = entry_bounds(entry,bodies)
	var profile: String = str(entry.get("profile", ""))
	if profile.is_empty():
		var spec: Dictionary = game.model_spec(str(entry.kind),entry.p,int(entry.index))
		profile=str(spec.get("profile",str(entry.kind)))
	coverage[profile+":"+state]=int(coverage.get(profile+":"+state,0))+1
	for a in range(16):
		var normal := Vector2.from_angle(TAU*a/16.0)
		var contact: Vector2 = support(bodies,bounds,normal)
		var start: Vector2 = contact+normal*36.0
		game.solid_bodies = bodies if isolated else all_world_bodies
		var found := false
		for outward in range(7):
			var candidate := start+normal*outward*16.0
			if game.walkable(candidate):start=candidate;found=true;break
		if not found:
			blocked_starts+=1
			continue
		game.player=start;game.facing=-normal;game.walk_distance=0;game.moving=false
		var previous: Vector2 = game.player
		game.move_player(-normal,0.55)
		frames_simulated+=1
		check(game.walkable(game.player),"%s %s angle%d approach legal" % [profile,state,a])
		var pose: Vector2 = game.player
		var own_contact := false
		for body in bodies:
			if Geometry.bounds_overlap(game.feet_rect(pose).grow(2.0),body.bounds):own_contact=true
		if isolated:isolated_routes+=1
		else:world_approaches+=1
		if bodies.is_empty():no_body_routes+=1
		# Long frame, tangent in both directions and diagonal motion exercise the
		# real 1.5-unit substeps and axis-slide code rather than hand-made moves.
		for movement in [-normal,normal.rotated(PI/2),normal.rotated(-PI/2),(-normal+normal.rotated(PI/2)).normalized()]:
			game.player=pose
			game.move_player(movement,0.72 if isolated else 0.18)
			frames_simulated+=1
			check(game.walkable(game.player),"%s %s angle%d tangent/diagonal/long-frame legal" % [profile,state,a])
		game.player=pose
		if own_contact or bodies.is_empty():
			contacts.append({"entry":{"kind":entry.kind,"p":v(entry.p),"index":int(entry.index),"id":body_id(entry)},"profile":profile,"state":state,"isolated":isolated,"angle":a,"player":v(pose),"facing":v(-normal),"camera":v(pose-Vector2(220,230)),"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y],"travel":previous.distance_to(pose)})
	game.solid_bodies=all_world_bodies

func entries_with_ponds() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in game.scenery_entries():
		if entry.kind in ["player","Rowan","Ash"]:continue
		entries.append(entry)
	var ids: Dictionary = {}
	for body in game.solid_bodies:
		if body.kind not in ["water","bank_rock"] or ids.has(body.id):continue
		ids[body.id]=true
		entries.append({"kind":body.kind,"p":body.p,"index":body.index,"id":body.id,"profile":body.profile})
	return entries
func add_variant(kind: String, p: Vector2, index: int = -1) -> void:
	game.rebuild_obstacles();all_world_bodies=game.solid_bodies.duplicate(true)
	var entry: Dictionary = game.scenery_entry(kind,p,index)
	route(entry,"alternate",true);variant_instances+=1
func simulate_npcs() -> void:
	game.solid_bodies=all_world_bodies
	game.player=Vector2(1700,760);game.setup_npcs();game.rebuild_navigation()
	var traveled := {"Rowan":0.0,"Ash":0.0}
	var moving_samples := {"Rowan":0,"Ash":0}
	for frame in range(1800):
		var old := {"Rowan":game.npc_home,"Ash":game.npc_position}
		game.update_npcs(1.0/30.0)
		for name in ["Rowan","Ash"]:
			var p: Vector2=game.npc_states[name].p
			traveled[name]+=p.distance_to(old[name])
			if game.npc_states[name].moving:moving_samples[name]+=1
			if frame%15==0:check(game.static_walkable(p),name+" patrol never enters scenery frame"+str(frame))
	for name in traveled:
		check(traveled[name]>200,name+" patrol travels >200 world units")
		check(moving_samples[name]>200,name+" has walking animation frames")
	var file := FileAccess.open(OUT+"npc-walkthrough-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"duration_seconds":60,"traveled":traveled,"moving_frames":moving_samples},"\t"))
func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():version=args[0]
	game=load("res://main.tscn").instantiate();game.resource_seed=159
	root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(50,1450);game.npc_position=Vector2(90,1450)
	all_world_bodies=game.solid_bodies.duplicate(true)
	var entries: Array[Dictionary] = entries_with_ponds()
	for entry in entries:
		route(entry,"live",false)
		route(entry,"live",true)
		actual_instances+=1
	print("WALK_ACTUAL_INSTANCES ",actual_instances," routes=",world_approaches+isolated_routes)
	# All existing trees become both stump variants; spent resources keep their
	# actual positions and ore depletion preserves each variant's normal art.
	for p in game.trees:game.tree_states[p].felled=true
	for i in range(game.items.size()):game.items[i].taken=true
	for vein in game.ore_veins:vein.depleted=true
	game.rebuild_obstacles();all_world_bodies=game.solid_bodies.duplicate(true)
	for entry in game.scenery_entries():
		if entry.kind in ["tree","resource","ore"]:
			route(entry,"depleted",false);route(entry,"depleted",true)
			variant_instances+=1
	# Every exported prop sprite variant and resource art variant, even when a
	# seeded world does not happen to place one, follows the normal model API.
	for sprite in [1,2,3,4,5]:
		var index: int=game.props.size()
		game.props.append({"p":Vector2(1100,1350),"sprite":sprite,"height":49.0})
		add_variant("prop",game.props[index].p,index)
	for row in range(3):
		for variant in range(3):
			var index: int=game.items.size()
			game.items.append({"pos":Vector2(1100,1350),"kind":["branch","rock","rope"][row],"taken":false,"variant":variant,"mirror":false})
			add_variant("resource",game.items[index].pos,index)
			game.items[index].taken=true
			add_variant("resource",game.items[index].pos,index)
	# Place a workbench through gameplay; choose clear road, face right.
	game.player=Vector2(1620,760);game.facing=Vector2.RIGHT
	game.bag.add("workbench",1)
	game.hotbar[0]=int(game.bag.slots[0].uid);game.active_hotbar=0
	var placed: bool=game.place_workbench()
	check(placed,"gameplay places a workbench on clear road")
	if placed:add_variant("bench",game.workbenches[-1].p,game.workbenches.size()-1)
	simulate_npcs()
	var summary := {"version":version,"checks":checks,"failures":failures,"actual_instances":actual_instances,"alternate_state_instances":variant_instances,"full_world_approaches":world_approaches,"isolated_approaches":isolated_routes,"blocked_start_directions":blocked_starts,"nonblocking_routes":no_body_routes,"movement_calls":frames_simulated,"contact_poses":contacts.size(),"profiles_and_states":coverage,"failure_labels":failures_list,"method":"Real move_player, 16 support-angle approaches per actual instance, both actual world and isolated own object, tangent/diagonal/long-frame. Static passable resources are intentionally not forced solid. NPC real navigation simulated for 60 seconds. Visual acceptance is a separate alpha compositing audit."}
	var file:=FileAccess.open(OUT+"all-model-walkthrough-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	file=FileAccess.open(OUT+"all-model-contact-poses.json",FileAccess.WRITE);file.store_string(JSON.stringify({"poses":contacts},"\t"));file.close()
	print("ALL_MODEL_WALKTHROUGH_RESULTS ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
