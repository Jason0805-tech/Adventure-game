extends SceneTree
const PaintedSkin=preload("res://animal_gait.gd")
const NativeSeams=preload("native_seams.gd")
func _initialize():call_deferred("run")
func run():
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var packed:Dictionary={};var body_vertices:=0;var leg_vertices:=0;var started:int=Time.get_ticks_msec()
	for species in metadata.species:
		var m:Dictionary=metadata.species[species]
		var cell:=Vector2(float(m.cell[0]),float(m.cell[1]))
		var image:=Image.load_from_file(m.path)
		for direction in range(8):
			var definition:Dictionary=m.source_skin[str(direction)]
			var entry:Dictionary=PaintedSkin.compile_entry(definition,cell,Vector2(cell.x*8,cell.y*float(m.frames)))
			entry["seams"]=NativeSeams.extract_native_seams(entry,definition,m,image)
			packed[str(species)+":"+str(direction)]=entry
			for owner in entry.parts:
				if int(owner)<0:body_vertices+=entry.parts[owner].source_points.size()
				else:leg_vertices+=entry.parts[owner].source_points.size()
			print("SKIN_COMPILED ",species,"/",direction)
	var file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.WRITE);file.store_var(packed);file.close()
	print("ALL_SKIN_TOPOLOGY_COMPILED ",packed.size()," bodyvertices=",body_vertices," legvertices=",leg_vertices," elapsed_ms=",Time.get_ticks_msec()-started)
	quit(0 if packed.size()==40 else 1)
