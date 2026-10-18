extends SceneTree
# Actual main._draw native Canvas coverage for the original-painted UV renderer.
# Overlapping staged animals isolate rendering; this is not a natural spawn test.
class TimedCanvas:
	extends "res://main.gd"
	var native_draw_calls := 0
	var native_draw_usec := 0
	var native_draw_max_usec := 0
	func _draw() -> void:
		var started := Time.get_ticks_usec()
		super._draw()
		var duration := Time.get_ticks_usec()-started
		native_draw_calls+=1;native_draw_usec+=duration
		native_draw_max_usec=maxi(native_draw_max_usec,duration)
const SPECIES := ["rabbit", "deer", "fox", "wolf", "bear"]
const HEADINGS := [0,45,90,135,180,225,270,315]
const POSITIONS := [Vector2(80,80),Vector2(1100,700),Vector2(2050,1400)]
const STATES := ["idle","wander","chase"]
const PHASES := 32
var game: Variant
var pose_draws := 0
var frames := 0
var mesh_checks := 0
var vertex_checks := 0
var triangle_checks := 0
var painted_triangle_checks := 0
var invalid: Array = []
var failure_count := 0
var bridge_quad_checks := 0
var bridge_triangle_checks := 0
var compiled_skin := {}
var input_hashes := {}
var fast_geometry := false
var bias_regression := false
var idle_geometry := {}
var images := {}
func _initialize() -> void:call_deferred("run")
func fail(label: String, context: Dictionary = {}) -> void:
	failure_count+=1
	if invalid.size() < 50: invalid.append({"reason":label,"pose":context})
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
func source_alpha(species: String, direction: int, p: Vector2) -> float:
	var image: Image = images[species]
	var x := clampi(int(p.x)+direction*384,0,image.get_width()-1)
	var y := clampi(int(p.y),0,image.get_height()-1)
	return image.get_pixel(x,y).a
func painted_triangle(species: String, direction: int, a: Vector2, b: Vector2, c: Vector2) -> bool:
	for p in [a,b,c,(a+b+c)/3.0,(a+b)*0.5,(a+c)*0.5,(b+c)*0.5]:
		if source_alpha(species,direction,p) > 0.10:return true
	return false
func check_bridges(gait: Variant, definition: Dictionary, drawing: Dictionary, context: Dictionary, metadata: Dictionary) -> void:
	var key: String = str(context.species)+":"+str(context.direction)
	if not compiled_skin.has(key):fail("Missing compiled native topology",context);return
	var entry: Dictionary = compiled_skin[key]
	if str(entry.get("hash",""))!=JSON.stringify(definition).sha256_text():fail("Compiled native topology is stale",context)
	var seams: Array = entry.get("seams",[])
	var bridges: Dictionary = gait.seam_geometry(definition,drawing.legs,seams)
	if bridges.get("kind","")!="native-edge-seam" or not bool(bridges.get("source_uv_area_zero",false)):fail("Untagged source-edge bridge geometry",context)
	if bridges.points.size()!=bridges.uvs.size() or bridges.points.size()%4!=0:fail("Malformed native edge bridge quad",context);return
	if bridges.indices.size()!=bridges.points.size()/4*6:fail("Malformed native edge bridge indices",context)
	for offset in range(0,bridges.points.size(),4):
		bridge_quad_checks+=1
		if bridges.uvs[offset]!=bridges.uvs[offset+2] or bridges.uvs[offset+1]!=bridges.uvs[offset+3]:fail("Bridge invents source pigment beyond its original native edge",context)
	for index in range(bridges.points.size()):
		var point: Vector2=bridges.points[index];var uv: Vector2=bridges.uvs[index]
		if not is_finite(point.x) or not is_finite(point.y) or not is_finite(uv.x) or not is_finite(uv.y):fail("Non-finite native bridge vertex",context)
		if uv.x<0 or uv.x>1 or uv.y<0 or uv.y>1:fail("Bridge UV leaves native paint atlas",context)
	for offset in range(0,bridges.indices.size(),3):
		bridge_triangle_checks+=1
		for corner in range(3):
			if int(bridges.indices[offset+corner])<0 or int(bridges.indices[offset+corner])>=bridges.points.size():fail("Native bridge index out of bounds",context)
	# Bridges intentionally extrude one original UV edge (zero source area).
	# They are underlays, not original painted surface triangles. All actual
	# source-painted triangles retain the strict positive-orientation assertion.

func check_geometry(gait: Variant, animal: Dictionary, phase: float) -> void:
	var species := str(animal.species)
	var pose: Dictionary = game.animal_pose(animal)
	var metadata: Dictionary = game.animal_metadata[species]
	var direction := int(pose.direction)
	var definition: Dictionary = metadata.get("source_skin",{}).get(str(direction),{})
	var context := {"species":species,"direction":direction,"state":animal.state,"phase":phase}
	if definition.is_empty():fail("Missing source-painted leg definition",context);return
	var cell := Vector2(float(metadata.cell[0]),float(metadata.cell[1]))
	var texture_size := Vector2(cell.x*8.0,cell.y*float(metadata.frames))
	var key := species+":"+str(direction)
	if not idle_geometry.has(key): idle_geometry[key]=gait.geometry(definition,0.0,false,cell,texture_size)
	var original: Dictionary = idle_geometry[key]
	var drawing: Dictionary = gait.geometry(definition,phase,bool(animal.moving),cell,texture_size)
	mesh_checks+=1
	if drawing.uvs != original.uvs:fail("Source UV changed while moving",context)
	if drawing.source_points != original.source_points:fail("Source paint coordinates changed",context)
	if drawing.indices != original.indices:fail("Source topology changed during gait",context)
	if not bool(animal.moving) and drawing.native_points != drawing.source_points:fail("Idle does not reconstruct full native silhouette",context)
	if bool(animal.moving):check_bridges(gait,definition,drawing,context,metadata)
	if drawing.indices.size()%3 != 0:fail("Indexed mesh does not contain complete triangles",context)
	if drawing.native_points.size()!=drawing.uvs.size():fail("A native vertex has no source UV",context)
	for index in range(drawing.native_points.size()):
		var point: Vector2 = drawing.native_points[index]
		var uv: Vector2 = drawing.uvs[index]
		vertex_checks+=1
		if not is_finite(point.x) or not is_finite(point.y) or not is_finite(uv.x) or not is_finite(uv.y):fail("Non-finite native mesh vertex",context)
		if uv.x < 0 or uv.x > 1 or uv.y < 0 or uv.y > 1:fail("Native UV leaves the unchanged source atlas",context)
	for offset in range(0,drawing.indices.size(),3):
		var ia: int = int(drawing.indices[offset]);var ib: int = int(drawing.indices[offset+1]);var ic: int = int(drawing.indices[offset+2])
		triangle_checks+=1
		if mini(ia,mini(ib,ic))<0 or maxi(ia,maxi(ib,ic))>=drawing.native_points.size():fail("Native mesh index out of bounds",context);continue
		var a: Vector2=drawing.source_points[ia];var b: Vector2=drawing.source_points[ib];var c: Vector2=drawing.source_points[ic]
		if not painted_triangle(species,direction,a,b,c):continue
		painted_triangle_checks+=1
		var source_sign: float = (b-a).cross(c-a)
		var na: Vector2=drawing.native_points[ia];var nb: Vector2=drawing.native_points[ib];var nc: Vector2=drawing.native_points[ic]
		var native_sign: float = (nb-na).cross(nc-na)
		if source_sign*native_sign <= 0:fail("A painted source triangle folds or collapses",context)
func run() -> void:
	fast_geometry=OS.get_cmdline_user_args().has("--fast-geometry")
	bias_regression=OS.get_cmdline_user_args().has("--bias-regression")
	for path in ["res://main.gd","res://animal_gait.gd","res://assets/animal_atlas.json","res://assets/animal-skin-topology.bin","res://world_lighting.gd"]:input_hashes[path]=FileAccess.get_sha256(path)
	var topology_file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.READ)
	if topology_file!=null:compiled_skin=topology_file.get_var();topology_file.close()
	game=TimedCanvas.new();game.resource_seed=161
	root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.phase="day";game.day_time=81;game.message_time=0
	var gait: Variant = load("res://animal_gait.gd")
	for species in SPECIES:
		var path: String = "res://assets/wildlife-"+str(species)+".png"
		var baseline := ProjectSettings.globalize_path("res://../adventure game 0.1.6/assets/wildlife-"+species+".png")
		if FileAccess.get_sha256(path)!=FileAccess.get_sha256(baseline):fail("Original .6 native atlas changed",{"species":species})
		images[species]=Image.load_from_file(path)
	var started := Time.get_ticks_msec()
	var render_start := 0
	var render_usec := 0
	for p in POSITIONS:
		if fast_geometry and p!=POSITIONS[0]:continue
		for state in STATES:
			if fast_geometry and state=="chase":continue
			for key in range(PHASES):
				var phase := float(key)/PHASES
				stage(p,state,phase)
				# UV/local deformation is independent of world translation; check each
				# unique pose once, then render it at all three requested world positions.
				if p==POSITIONS[0] and (state!="idle" or key==0) and (not bias_regression or state!="chase"):
					for animal in game.wildlife.entries():check_geometry(gait,animal,phase)
				if fast_geometry:continue
				if bias_regression and key not in [0,10,21]:continue
				render_start=Time.get_ticks_usec()
				game.queue_redraw()
				await process_frame
				await process_frame
				render_usec+=Time.get_ticks_usec()-render_start
				frames+=1;pose_draws+=SPECIES.size()*HEADINGS.size()
			print("NATIVE_GAIT_STRESS_PROGRESS p=",p," state=",state," poses=",pose_draws," invalid=",failure_count)
	for path in input_hashes:
		if FileAccess.get_sha256(path)!=input_hashes[path]:fail("Release input changed during stress",{"path":path})
	var result := {"input_sha256":input_hashes,"mode":"fast-geometry" if fast_geometry else ("final-bias-regression" if bias_regression else "full-native-canvas"),"frames":frames,"pose_draws":pose_draws,"native_edge_bridge_quads":bridge_quad_checks,"native_edge_bridge_triangles":bridge_triangle_checks,"native_uv_mesh_checks":mesh_checks,"native_vertex_checks":vertex_checks,"indexed_triangle_checks":triangle_checks,"painted_triangle_checks":painted_triangle_checks,"invalid":failure_count,"elapsed_ms":Time.get_ticks_msec()-started,"queued_redraw_cycle_mean_ms":render_usec/1000.0/maxi(1,frames),"actual_native_draw_calls":game.native_draw_calls,"native_draw_command_mean_ms":game.native_draw_usec/1000.0/maxi(1,game.native_draw_calls),"native_draw_command_max_ms":game.native_draw_max_usec/1000.0,"method":"Fast native UV geometry checks, no Canvas redraw claim." if fast_geometry else "Actual release main.gd native Canvas queued redraws with original native UV texture; staged independent rendering coverage, not a manual GPU playthrough."}
	var file:=FileAccess.open("res://../../tests/0.1.6.2/"+("uv-fast-stress-result.json" if fast_geometry else ("native-bias-regression-result.json" if bias_regression else "native-gait-stress-result.json")),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"))
	print("UV_FAST_STRESS_RESULT " if fast_geometry else ("NATIVE_BIAS_REGRESSION_RESULT " if bias_regression else "NATIVE_GAIT_STRESS_RESULT "),JSON.stringify(result))
	if not invalid.is_empty():printerr("INVALID_POSES ",JSON.stringify(invalid))
	game.queue_free();quit(0 if failure_count==0 else 1)
