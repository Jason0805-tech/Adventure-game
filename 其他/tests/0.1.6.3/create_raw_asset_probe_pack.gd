extends SceneTree
const FOLDER="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.3"
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FOLDER+"/packaged_asset_manifest.json"))
	var pack:=PCKPacker.new()
	if pack.pck_start(FOLDER+"/raw-assets-probe.pck")!=OK:quit(2);return
	if pack.add_file("res://project.godot",ProjectSettings.globalize_path("res://project.godot"))!=OK:quit(2);return
	for path in manifest:
		if pack.add_file(path,ProjectSettings.globalize_path(path))!=OK:push_error("Cannot pack "+str(path));quit(2);return
	var result:=pack.flush()
	print("RAW_ASSET_PROBE_PACK files=",manifest.size()," result=",result)
	quit(0 if result==OK else 1)
