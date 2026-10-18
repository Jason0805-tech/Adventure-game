extends SceneTree
const OUT="res://../../tests/0.1.5.11/"
var game:Variant
var checks:=0
var failures:=0
var labels:Array=[]
var routes:Array=[]
var simulated_frames:=0
var walked_distance:=0.0
var macro_destinations:=0
var state_changes:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if labels.size()<100:labels.append(label);push_error("PASSAGE_FAIL "+label)
func pair(p:Vector2)->Array:return [p.x,p.y]
func new_game()->void:
	if game!=null:game.queue_free()
	game=load("res://main.tscn").instantiate();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(70,60);game.npc_position=Vector2(110,60)
func walk_segment(target:Vector2,label:String)->bool:
	var delta:Vector2=target-game.player
	var limit:=ceili(delta.length()/2.0)+20
	for frame in range(limit):
		delta=target-game.player
		if delta.length()<0.015:return true
		var previous:Vector2=game.player
		game.move_player(delta.normalized(),minf(1.0/60.0,delta.length()/game.SPEED))
		game.update_walk(previous.distance_to(game.player));walked_distance+=previous.distance_to(game.player);simulated_frames+=1
		if not game.walkable(game.player):check(false,label+" movement entered a ground solid");return false
		if previous.distance_to(game.player)<0.0001:check(false,label+" path segment blocked at "+str(game.player)+" target="+str(target));return false
	check(false,label+" failed to reach waypoint in finite frames");return false
func macro_route(goal:Vector2,label:String)->bool:
	var from:Vector2i=game.nav_cell(game.player);var to:Vector2i=game.nav_cell(goal)
	check(from.x>=0 and to.x>=0,label+" start/destination have actor-safe navigation cells")
	if from.x<0 or to.x<0:return false
	var path:PackedVector2Array=game.nav_grid.get_point_path(from,to)
	check(not path.is_empty(),label+" full-world route exists")
	if path.is_empty():return false
	var start:Vector2=game.player
	var completed:=true
	for waypoint in path:
		if not walk_segment(waypoint,label):completed=false;break
	var selected:Vector2=path[-1]
	check(completed and game.player.distance_to(selected)<0.1,label+" real player follows every waypoint without teleport")
	check(selected.distance_to(goal)<72,label+" destination approach stays near actual goal")
	routes.append({"label":label,"start":pair(start),"requested":pair(goal),"selected":pair(selected),"end":pair(game.player),"waypoints":path.size(),"completed":completed})
	macro_destinations+=1
	return completed
func check_arch()->void:
	# Source openingx235/468, not the game.gate anchor (rightpillarx342.7).
	for x in [1989.0,1991.0,1994.0]:
		for sign_y in [-1.0,1.0]:
			var start:=Vector2(x,360 if sign_y<0 else 155)
			game.player=start;var target:Vector2=start+Vector2(0,sign_y*205.0)
			check(game.walkable(start),"actual arch approach start clear "+str(start))
			check(walk_segment(target,"arch centerline "+str(x)),"walk through actual arch in both directions x="+str(x))
			check(game.player.distance_to(target)<0.1,"same .10 repro reaches opposite side x="+str(x)+" dir="+str(sign_y))
	# Offset1997 extends the28unit boots into the real right masonry foot.
	# It must stop at that foot rather than being widened into solid stone.
	for sign_y in [-1.0,1.0]:
		var start:=Vector2(1997,360 if sign_y<0 else 155)
		game.player=start;game.move_player(Vector2(0,sign_y),205.0/game.SPEED)
		check(game.walkable(game.player),"near-column outer lane leaves boots legal")
		check(absf(game.player.y-start.y-sign_y*205)>40,"outer lane correctly blocked by actual right masonry foot")
	# The navigation graph itself must cross the opening. A macro path could
	# otherwise go around both pillars and conceal a closed center corridor.
	game.player=Vector2(1994,360)
	var start:Vector2i=game.nav_cell(game.player);var goal:Vector2i=game.nav_cell(Vector2(1994,155))
	var path:PackedVector2Array=game.nav_grid.get_point_path(start,goal)
	check(not path.is_empty(),"arch front/back connected in actual NPC AStar graph")
	var max_dx:=0.0
	for point in path:max_dx=maxf(max_dx,absf(point.x-1994))
	check(max_dx<=14,"arch nav path stays in opening instead of detouring around pillars")
	for point in path:
		if not walk_segment(point,"arch navigation waypoint"):break
	check(game.player.distance_to(game.nav_grid.get_point_position(goal))<0.1,"real player traverses AStar arch path")
	routes.append({"label":"arch direct navigation","waypoints":path.size(),"max_x_deviation":max_dx,"end":pair(game.player)})
func check_local_nav(point:Vector2,label:String)->void:
	var count:=0
	for y in range(game.nav_grid.region.size.y):
		for x in range(game.nav_grid.region.size.x):
			var id:=Vector2i(x,y);var world:Vector2=game.nav_grid.get_point_position(id)
			if absf(world.x-point.x)>120 or absf(world.y-point.y)>120:continue
			check(game.nav_grid.is_point_solid(id)==not game.static_walkable(world),label+" navcell matches actor physics "+str(id));count+=1
	check(count>50,label+" nearby navigation coverage")
func equip(id:String)->void:
	game.bag.add(id,1);var slot:int=game.bag.first(id)
	game.bind_hotbar(int(game.bag.slots[slot].uid),0);game.active_hotbar=0
func stand_near(point:Vector2)->bool:
	for radius in [38.0,50.0,65.0,75.0]:
		for angle in range(16):
			var candidate:Vector2=point+Vector2.from_angle(TAU*angle/16.0)*radius
			if game.walkable(candidate):game.player=candidate;return true
	return false
func dynamic_changes()->void:
	new_game()
	var index:=-1
	for i in range(game.items.size()):
		if game.items[i].kind=="rock":index=i;break
	check(index>=0,"live collectible rock exists")
	if index>=0:
		var p:Vector2=game.items[index].pos;var before:int=game.nav_revision
		game.collect_item(index)
		check(game.items[index].taken,"collecting removes live rock state")
		check(game.nav_revision==before+1,"collecting refreshes navigation revision")
		var active_body:=false
		for body in game.solid_bodies:
			if body.kind=="resource" and body.index==index and game.body_active(body):active_body=true
		check(not active_body,"collected rock leaves no active blocking body")
		check_local_nav(p,"collected rock");state_changes.append("collect rock")
	equip("stone_axe")
	var tree:Vector2=game.trees[0];game.tree_states[tree].hp=1
	check(stand_near(tree),"tree harvesting begins at legal nearby ground")
	var before:int=game.nav_revision
	check(game.begin_action({"kind":"tree","pos":tree}),"real axe action starts")
	game.commit_action();game.cancel_action()
	check(not game.tree_live(tree),"axe final hit creates stump")
	check(game.nav_revision==before+1,"tree-to-stump refreshes navigation")
	var stump_body:=false
	for body in game.solid_bodies:
		if body.kind=="tree" and body.p==tree and str(body.profile).begins_with("stump_"):stump_body=true
	check(stump_body,"felled tree body replaced with grounded stump profile")
	check_local_nav(tree,"felled tree stump");state_changes.append("fell tree")
	equip("pickaxe");var vein:Dictionary=game.ore_veins[0];vein.hp=1
	check(stand_near(vein.p),"ore harvesting begins on legal nearby ground")
	before=game.nav_revision
	check(game.begin_action({"kind":"ore","pos":vein.p,"index":0}),"real pickaxe action starts")
	game.commit_action();game.cancel_action()
	check(vein.depleted,"pickaxe final hit depletes ore")
	check(game.nav_revision==before+1,"ore depletion refreshes navigation")
	check_local_nav(vein.p,"depleted ore");state_changes.append("mine ore")
	equip("workbench")
	var placed:=false
	before=game.nav_revision
	for y in range(740,1300,80):
		for x in range(800,1800,80):
			var p:=Vector2(x,y)
			if not game.walkable(p):continue
			game.player=p;game.facing=Vector2.DOWN
			if game.can_place_bench(game.place_point()) and game.target_line_clear(game.place_point()):
				placed=game.place_workbench();break
		if placed:break
	check(placed,"workbench placed through actual gameplay on legal ground")
	check(game.nav_revision==before+1,"placed workbench rebuilds navigation")
	if placed:check_local_nav(game.workbenches[-1].p,"placed workbench");state_changes.append("place workbench")
func run()->void:
	new_game();check_arch()
	# A single continuous circuit, one initial spawn, no route teleports. Each
	# leg uses the real full-world AStar path and move_player at60Hz.
	game.player=Vector2(360,760)
	check(game.walkable(game.player),"normal player spawn is legal")
	var goals:Array=[
		[Vector2(455,780),"camp and Rowan approach"], [Vector2(350,480),"behind cabin under elevated roof"],
		[Vector2(150,150),"northwest quadrant"], [Vector2(1080,615),"main pond south shore"],
		[Vector2(1510,550),"eastern pond approach"], [Vector2(2030,150),"northeast quadrant"],
		[Vector2(1994,360),"arch front"], [Vector2(1994,155),"arch rear"],
		[Vector2(2050,1320),"southeast quadrant"], [Vector2(1280,1020),"Ash patrol approach"],
		[Vector2(675,1260),"southern pond approach"], [Vector2(150,1320),"southwest quadrant"]]
	for i in range(game.ore_veins.size()):goals.append([game.ore_veins[i].p+Vector2(0,70),"ore vein "+str(i)+" approach"])
	goals.append([Vector2(455,780),"return to camp"])
	for target in goals:
		if not macro_route(target[0],target[1]):break
	var expected_goals:int=goals.size()
	check(macro_destinations==expected_goals,"all macro destinations visited through continuous actual player walk")
	dynamic_changes()
	var summary:Dictionary={"version":"0.1.5.11","checks":checks,"failures":failures,"macro_destinations":macro_destinations,"expected_macro_destinations":expected_goals,"movement_frames":simulated_frames,"distance_walked":walked_distance,"route_records":routes,"state_changes":state_changes,"failure_labels":labels,"method":"Actual seeded full-world movement at60Hz; exact .10 arch repro both directions, AStar route must stay inside opening; continuous full-map circuit without route teleports; normal harvest/placement APIs must refresh physics and local navigation. NPC positions separated during focused static scenery/path tests."}
	var file:=FileAccess.open(OUT+"passage-navigation-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("PASSAGE_NAVIGATION_RESULTS ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
