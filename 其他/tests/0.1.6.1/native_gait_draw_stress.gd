extends SceneTree
# Real Canvas stress test: every pose is routed through the release main._draw().
# Staged overlapping animals isolate rendering; this is not a natural spawn test.
const SPECIES := ["rabbit", "deer", "fox", "wolf", "bear"]
const HEADINGS := [0,45,90,135,180,225,270,315]
const POSITIONS := [Vector2(80,80),Vector2(1100,700),Vector2(2050,1400)]
const STATES := ["idle","wander","chase"]
const PHASES := 32
var game: Variant
var pose_draws := 0
var frames := 0
var polygon_checks := 0
var invalid: Array = []
func _initialize() -> void:call_deferred("run")
func stage(p: Vector2, state: String, phase: float) -> void:
	game.wildlife.animals.clear()
	var uid := 1
	for species in SPECIES:
		var stride: float = game.wildlife.Data.info(species).stride
		for angle in HEADINGS:
			var radians := deg_to_rad(float(angle))
			game.wildlife.animals.append({"uid":uid,"species":species,"p":p,"home":p,"goal":p,"facing":Vector2(sin(radians),cos(radians)),"moving":state!="idle","walk":stride*phase,"state":state,"age":10.0,"hitflash":0.0,"hp":float(game.wildlife.Data.info(species).health),"timer":1.0})
			uid += 1
	game.player=p+Vector2(100,0)
	game.camera=Vector2(clampf(p.x-550,0,1100),clampf(p.y-360,0,780))
func run() -> void:
	game=load("res://main.gd").new()
	game.resource_seed=161
	root.add_child(game)
	game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.phase="day";game.day_time=81;game.message_time=0
	var gait: Variant = load("res://animal_gait.gd")
	var started := Time.get_ticks_msec()
	for p in POSITIONS:
		for state in STATES:
			for key in range(PHASES):
				var phase := float(key)/PHASES
				stage(p,state,phase)
				# Validate the exact native draw inputs. Limbs now triangulate in local
				# space before world translation, avoiding world-coordinate float loss.
				for animal in game.wildlife.entries():
					var pose: Dictionary = game.animal_pose(animal)
					var geometry: Dictionary = gait.geometry(animal,game.animal_metadata[animal.species],pose)
					var polygons: Array = geometry.limbs.duplicate()
					polygons.append({"points":geometry.body_points})
					for polygon in polygons:
						polygon_checks+=1
						if Geometry2D.triangulate_polygon(polygon.get("local_points",polygon.points)).is_empty():
							invalid.append({"species":animal.species,"position":[p.x,p.y],"state":state,"heading":pose.direction,"phase":phase})
				game.queue_redraw()
				# RenderingServer consumes the actual Canvas queue between these ticks.
				await process_frame
				await process_frame
				frames+=1;pose_draws+=SPECIES.size()*HEADINGS.size()
			print("NATIVE_GAIT_STRESS_PROGRESS p=",p," state=",state," poses=",pose_draws," invalid=",invalid.size())
	var result := {"frames":frames,"pose_draws":pose_draws,"native_polygon_checks":polygon_checks,"invalid":invalid.size(),"elapsed_ms":Time.get_ticks_msec()-started,"method":"Actual main.gd native Canvas queued redraws, staged independent rendering coverage; no manual GPU playthrough claim."}
	var file:=FileAccess.open("res://../../tests/0.1.6.1/native-gait-stress-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("NATIVE_GAIT_STRESS_RESULT ",JSON.stringify(result))
	if not invalid.is_empty():printerr("INVALID_POSES ",JSON.stringify(invalid.slice(0,20)))
	game.queue_free();quit(0 if invalid.is_empty() else 1)
