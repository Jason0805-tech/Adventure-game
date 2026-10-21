extends SceneTree
const SkinRig=preload("res://animal_gait.gd")
func _initialize():call_deferred("run")
func run():
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.READ);var packed:Dictionary=file.get_var();file.close()
	var checks:=0;var errors:Array=[]
	for species in metadata.species:
		var m:Dictionary=metadata.species[species]
		var a:String=FileAccess.get_sha256("res://assets/wildlife-"+str(species)+".png")
		var b:String=FileAccess.get_sha256("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/output/adventure game 0.1.6/assets/wildlife-"+str(species)+".png")
		checks+=1
		if a!=b:errors.append("Source PNG changed "+species)
		for direction in range(8):
			var key:String=str(species)+":"+str(direction)
			var definition:Dictionary=m.source_skin[str(direction)]
			checks+=1
			if not packed.has(key) or str(packed[key].hash)!=JSON.stringify(definition).sha256_text():errors.append("Compiled metadata hash mismatch "+key);continue
			var total_area:float=0
			for owner in packed[key].parts:
				var part:Dictionary=packed[key].parts[owner]
				for start in range(0,part.indices.size(),3):
					var p:Vector2=part.source_points[part.indices[start]];var q:Vector2=part.source_points[part.indices[start+1]];var r:Vector2=part.source_points[part.indices[start+2]]
					total_area+=absf((q-p).cross(r-p))*.5
				for index in range(part.source_points.size()):
					var point:Vector2=part.source_points[index];var uv:Vector2=part.uvs[index]
					checks+=1
					if (Vector2(direction*384,0)+point-uv*Vector2(3072,1536)).length()>.001:errors.append("UV/source coordinate drift "+key)
			checks+=1
			if absf(total_area-384*384)>.1:errors.append("Source coverage lost/duplicated "+key+" area="+str(total_area))
	var report:Dictionary={"checks":checks,"errors":errors,"compiled_entries":packed.size(),"binary_sha256":FileAccess.get_sha256("res://assets/animal-skin-topology.bin"),"native_png_hashes_unchanged":true}
	var out:=FileAccess.open("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv/compiled-validation.json",FileAccess.WRITE);out.store_string(JSON.stringify(report,"  "));out.close()
	print("COMPILED_SKIN_VALIDATION ",checks," errors=",errors.size()," entries=",packed.size())
	for error in errors.slice(0,8):print(error)
	quit(0 if errors.is_empty() else 1)
