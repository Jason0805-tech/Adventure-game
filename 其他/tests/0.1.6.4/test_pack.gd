extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../preservation-results.json")).sha256
	var source:Dictionary={}
	for name in manifest:
		if name.ends_with(".png") or name.ends_with(".json"):source[name]=manifest[name]
	check(ProjectSettings.load_resource_pack(ProjectSettings.globalize_path("res://web/game.pck"),true),"final PCK mounts")
	for name in source:
		check(FileAccess.file_exists("res://"+name),"raw native file in PCK "+name)
		check(FileAccess.get_sha256("res://"+name)==source[name],"exact native bytes in PCK "+name)
	for name in ["main","survival_balance","sanity_system","predator_behavior","wildlife","wildlife_data","mobile_ui","mobile_controls","world_lighting"]:
		check(ResourceLoader.load("res://"+name+".gd")!=null,"compiled module loads "+name)
	var game:Variant=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);await process_frame
	check(game.sanity==100 and game.Balance.HUNGER_PER_SECOND>0.13,"pack boots new survival runtime")
	check(game.day_duration==180 and game.night_duration==90,"pack preserves clocks")
	check(game.animal_atlases.size()==5 and game.pond_paint_layers.size()==3,"native animal and pond assets decode in export")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"native_files":source.size()}
	FileAccess.open(ProjectSettings.globalize_path("res://../pack-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("PACK_RESULTS ",JSON.stringify(report));game.queue_free();quit(0 if failures.is_empty() else 1)
