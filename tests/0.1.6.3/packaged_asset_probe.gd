extends SceneTree
## Use editor --main-pack exported/index.pck --script /absolute/probe.gd --
## --manifest /absolute/packaged_asset_manifest.json. It reads the actual PCK,
## sequentially decodes full original PNGs and validates native size/hash.
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func _run()->void:
	var manifest_path:=""
	var args:=OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i]=="--manifest":manifest_path=args[i+1]
	if manifest_path.is_empty():push_error("Provide --manifest /absolute/packaged_asset_manifest.json");quit(2);return
	var raw:Variant=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not raw is Dictionary:push_error("Invalid external expected manifest");quit(2);return
	var manifest:Dictionary=raw
	var images:=0;var jsons:=0;var binaries:=0;var decoded_pixels:=0
	var compiled_topology:Dictionary={}
	for path in manifest:
		var expected:Dictionary=manifest[path]
		check(FileAccess.file_exists(path),"Original packed file absent "+str(path))
		if not FileAccess.file_exists(path):continue
		var bytes:=FileAccess.get_file_as_bytes(path)
		check(bytes.size()==int(expected.bytes),"Packed original size mismatch "+str(path))
		var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
		check(hash.finish().hex_encode()==str(expected.sha256),"Packed original hash mismatch "+str(path))
		if str(path).ends_with(".png"):
			check(bytes.size()>=8 and bytes.slice(0,8)==PackedByteArray([137,80,78,71,13,10,26,10]),"PNG is raw native source, not CTEX "+str(path))
			var image:=Image.new()
			var error:=image.load_png_from_buffer(bytes)
			check(error==OK and not image.is_empty(),"Packed PNG buffer decode "+str(path))
			if image.is_empty():continue
			check(image.get_size()==Vector2i(int(expected.width),int(expected.height)),"Native resolution preserved "+str(path))
			# Also exercise the exact res:// filename loader. Never globalize PCK paths.
			image=null
			image=Image.load_from_file(path)
			check(image!=null and not image.is_empty(),"Packed res:// Image.load_from_file "+str(path))
			decoded_pixels+=int(expected.width)*int(expected.height);images+=1
		elif str(path).ends_with(".json"):
			var parsed:Variant=JSON.parse_string(bytes.get_string_from_utf8())
			check(parsed is Dictionary or parsed is Array,"Packed JSON decode "+str(path));jsons+=1
		elif str(path).ends_with(".bin"):
			var file:=FileAccess.open(path,FileAccess.READ)
			var parsed:Variant=file.get_var();file.close()
			check(parsed is Dictionary and parsed.size()==40,"Compiled native topology 40 headings")
			if parsed is Dictionary:
				compiled_topology=parsed
				for key in parsed:
					check(parsed[key].has("hash") and parsed[key].has("parts") and parsed[key].has("seams"),"Packed compiled topology schema "+str(key))
			binaries+=1
	var metadata_raw:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	if metadata_raw is Dictionary:
		for species in metadata_raw.get("species",{}):
			for direction in range(8):
				var key:String=str(species)+":"+str(direction)
				var definition:Dictionary=metadata_raw.species[species].source_skin[str(direction)]
				check(compiled_topology.has(key) and str(compiled_topology[key].hash)==JSON.stringify(definition).sha256_text(),"Compiled metadata signature avoids browser fallback build "+key)
	check(ThemeDB.fallback_font!=null,"English fallback font bundled in engine")
	if ThemeDB.fallback_font!=null:check(ThemeDB.fallback_font.get_string_size("Forest Wanderer",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x>0,"English fallback glyph metrics")
	print("PACKAGED_ASSET_PROBE images=",images," json=",jsons," bin=",binaries," original_pixels=",decoded_pixels," checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty()else 1)
