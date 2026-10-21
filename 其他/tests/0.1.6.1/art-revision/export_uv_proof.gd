extends SceneTree
const PaintedSkin=preload("painted_skin.gd")
const PATH="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.1/art-revision"
func points(raw:PackedVector2Array)->Array:
	var a:Array=[]
	for p in raw:a.append([p.x,p.y])
	return a
func _initialize():call_deferred("run")
func run():
	var defs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH+"/source_legs.json"))
	var result:Dictionary={}
	for species in defs.species:
		var def:Dictionary=defs.species[species]["2"]
		var idle:Dictionary=PaintedSkin.geometry(def,0,false)
		var frames:Array=[]
		for frame in range(24):
			var drawing:Dictionary=PaintedSkin.geometry(def,float(frame)/24,true)
			frames.append(points(drawing.native_points))
		result[species]={"source_points":points(idle.source_points),"idle_points":points(idle.native_points),"indices":Array(idle.indices),"frames":frames,"definition":def}
		print("UV_PROOF_SPECIES_READY ",species)
	var file:=FileAccess.open(PATH+"/uv-proof-geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("UV_PROOF_EXPORT_READY")
	quit()
