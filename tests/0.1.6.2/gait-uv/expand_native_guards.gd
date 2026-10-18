extends SceneTree
const TEST="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv"
func area(points:PackedVector2Array)->float:
	var sum:float=0
	for i in range(points.size()):sum+=points[i].cross(points[(i+1)%points.size()])
	return absf(sum)*.5
func _initialize():call_deferred("run")
func run():
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var changed:=0
	for species in metadata.species:
		var m:Dictionary=metadata.species[species]
		for direction in m.source_skin:
			for leg in m.source_skin[direction].legs:
				if float(leg.get("source_guard_padding",0.0))>=2.0:continue
				var polygon:=PackedVector2Array()
				for raw in leg.mask:polygon.append(Vector2(float(raw[0]),float(raw[1])))
				var expanded:Array=Geometry2D.offset_polygon(polygon,2.0,Geometry2D.JOIN_ROUND)
				var selected:PackedVector2Array=polygon;var largest:float=0
				for candidate in expanded:
					if area(candidate)>largest:largest=area(candidate);selected=candidate
				var raw:Array=[]
				for point in selected:raw.append([point.x,point.y])
				leg.mask=raw;leg["source_guard_padding"]=2.0;changed+=1
		var source_path:String=TEST+"/source-legs-"+str(species)+".json"
		var source:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_path));source.species[species]=m.source_skin
		var author:=FileAccess.open(source_path,FileAccess.WRITE);author.store_string(JSON.stringify(source,"  "));author.close()
	var file:=FileAccess.open("res://assets/animal_atlas.json",FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "));file.close()
	print("NATIVE_GUARDS_EXPANDED ",changed," sourcelegguards2nativepixels; originalRGBAunchanged")
	quit()
