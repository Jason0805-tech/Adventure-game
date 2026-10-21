extends SceneTree
func _initialize()->void:
	var kept_exists:=FileAccess.file_exists("res://kept.png")
	var imported_exists:=FileAccess.file_exists("res://imported.png")
	var imported_resource_exists:=ResourceLoader.exists("res://imported.png")
	var kept:=Image.load_from_file("res://kept.png")
	var globalized:=ProjectSettings.globalize_path("res://kept.png")
	var globalized_exists:=FileAccess.file_exists(globalized)
	var ok:bool=kept_exists and not imported_exists and imported_resource_exists and kept!=null and not kept.is_empty()
	print("EXPORTED_KEEP_FILE_PROOF ",JSON.stringify({"kept_raw_exists":kept_exists,"imported_raw_exists_despite_include_png":imported_exists,"imported_resource_exists":imported_resource_exists,"kept_original_decodes":kept!=null and not kept.is_empty(),"globalized_path":globalized,"globalized_file_exists":globalized_exists,"pass":ok}))
	quit(0 if ok else 1)
