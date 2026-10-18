extends SceneTree

func _initialize() -> void:
	var records: Dictionary = {}
	for property in ProjectSettings.get_property_list():
		var key: String = str(property.name)
		if (key.contains("hidpi") or key.contains("anti_aliasing") or key.contains("texture_filter") or key.contains("stretch/") or key.contains("viewport_width") or key.contains("viewport_height") or key.contains("window_width_override") or key.contains("window_height_override")):
			records[key] = ProjectSettings.get_setting(key)
	var requested := ["display/window/dpi/allow_hidpi", "rendering/anti_aliasing/quality/msaa_2d", "rendering/anti_aliasing/quality/screen_space_aa", "rendering/anti_aliasing/quality/use_debanding", "rendering/textures/default_filters/use_nearest_mipmap_filter", "rendering/textures/canvas_textures/default_texture_filter", "display/window/stretch/mode"]
	for key in requested:
		if not records.has(key): records[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key, "unavailable")}
	var path := "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.10/render-settings-source0159.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine_version":Engine.get_version_info(), "display_server":DisplayServer.get_name(), "settings":records, "msaa_2d_values":{"disabled":Viewport.MSAA_DISABLED,"2x":Viewport.MSAA_2X,"4x":Viewport.MSAA_4X,"8x":Viewport.MSAA_8X}, "note":"Headless settings inspection; does not measure a physical display backing scale or validate native GPU output."},"\t"))
	print(JSON.stringify(records))
	quit()
