extends SceneTree
const Seams=preload("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv/native_seams.gd")
const OUT="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv"
func _initialize()->void:call_deferred("run")
func run()->void:
	var file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.READ);var packed:Dictionary=file.get_var();file.close()
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var report:Dictionary={};var seam_data:Dictionary={};var total:=0
	for species in meta.species:
		var m:Dictionary=meta.species[species];var image:=Image.new();image.load("res://assets/wildlife-"+species+".png")
		for direction in range(8):
			var key:String=species+":"+str(direction);var seams:Array=Seams.extract_native_seams(packed[key],m.source_skin[str(direction)],m,image)
			report[key]=Seams.last_stats.duplicate(true);seam_data[key]=seams;total+=seams.size()
			print("NATIVE_SEAMS ",key," ",Seams.last_stats)
	file=FileAccess.open(OUT+"/native-seams-data.bin",FileAccess.WRITE);file.store_var(seam_data);file.close()
	file=FileAccess.open(OUT+"/native-seams-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("NATIVE_SEAMS_RESULT headings=",report.size()," opaque_seams=",total)
	quit(0 if report.size()==40 else 1)
