extends SceneTree
const PaintSkin=preload("res://animal_gait.gd")
const OUT="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv/independent_geometry"
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func vecs(points:PackedVector2Array)->Array:
	var result:Array=[]
	for p in points:result.append([p.x,p.y])
	return result
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func _run()->void:
	if not FileAccess.file_exists("res://assets/animal-skin-topology.bin"):
		push_error("Compile the production topology before independent audit.");quit(2);return
	DirAccess.make_dir_recursive_absolute(OUT)
	var file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.READ)
	var packed:Dictionary=file.get_var();file.close()
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var headings:=0;var moving_vertices:=0
	for species in meta.species:
		var metadata:Dictionary=meta.species[species]
		for direction in range(8):
			var definition:Dictionary=metadata.source_skin[str(direction)]
			var key:String=str(species)+":"+str(direction)
			check(packed.has(key),"Missing compiled heading "+key)
			if not packed.has(key):continue
			var entry:Dictionary=packed[key]
			check(entry.hash==JSON.stringify(definition).sha256_text(),"Stale compiled metadata "+key)
			var result:Dictionary={"species":species,"direction":direction,"definition":definition,"anchor":metadata.anchor,"scale":float(metadata.world_height)/float(metadata.reference_height_px),"parts":[]}
			for owner in entry.parts:
				var source:Dictionary=entry.parts[owner]
				var record:Dictionary={"owner":int(owner),"source":vecs(source.source_points),"uvs":vecs(source.uvs),"indices":Array(source.indices),"frames":[]}
				if int(owner)>=0:
					var leg:Dictionary=definition.legs[int(owner)]
					moving_vertices+=source.source_points.size()
					for p in source.source_points:
						check(PaintSkin.deform_leg(p,leg,PaintSkin.posed_leg(leg,0.0,false),false)==p,"Idle source point changed "+key)
					for frame in range(25):
						var phase:float=frame/24.0
						var posed:Dictionary=PaintSkin.posed_leg(leg,phase,true)
						var points:=PackedVector2Array()
						for p in source.source_points:points.append(PaintSkin.deform_leg(p,leg,posed,true))
						record.frames.append(vecs(points))
					check(record.frames[0]==record.frames[24],"Cycle wrap differs "+key+"/"+str(owner))
				result.parts.append(record)
			var out:=FileAccess.open(OUT+"/"+str(species)+"-"+str(direction)+".json",FileAccess.WRITE)
			out.store_string(JSON.stringify(result));out.close()
			headings+=1
			print("INDEPENDENT_GEOMETRY_EXPORTED ",key)
	print("INDEPENDENT_GEOMETRY_RESULT headings=",headings," moving_vertices=",moving_vertices," checks=",checks," failures=",failures.size())
	quit(0 if headings==40 and failures.is_empty() else 1)
