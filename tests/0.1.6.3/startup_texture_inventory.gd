extends SceneTree
func _initialize()->void:call_deferred("_run")
func _run()->void:
	var started:=Time.get_ticks_msec()
	var world=load("res://main.gd").new()
	world.load_art()
	var groups:Dictionary={
		"avatar_unarmed":[world.avatar_unarmed],"avatar_armed":[world.avatar_armed],"avatar_use":[world.avatar_use],
		"npc_atlases":world.npc_atlases.values(),"rowan_lantern":[world.rowan_lantern],"animal_atlases":world.animal_atlases.values(),
		"scenery_and_icons":world.art+world.resource_art+world.pond_art+world.variant_art+world.equipment_art+world.blend_art+world.harvest_art+world.prop_art+world.status_art+world.utility_icons+world.utility_props,
		"meadow":[world.meadow]}
	var total:=0;var seen:Dictionary={};var result:Dictionary={"groups":{},"retained_model_image_bytes":0}
	for key in groups:
		var amount:=0
		for texture in groups[key]:
			if texture==null or seen.has(texture.get_instance_id()):continue
			seen[texture.get_instance_id()]=true
			var image:Image=texture.get_image()
			if image!=null:amount+=image.get_data_size()
		result.groups[key]={"count":groups[key].size(),"image_rgba_mip_bytes":amount}
		total+=amount
	for image in world.model_images.values():result.retained_model_image_bytes+=image.get_data_size()
	result["startup_texture_rgba_mip_bytes"]=total
	result["unique_texture_count"]=seen.size()
	result["load_art_ms"]=Time.get_ticks_msec()-started
	var out:=FileAccess.open("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.3/startup-texture-inventory.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(result,"  "));out.close()
	print("STARTUP_TEXTURE_INVENTORY ",JSON.stringify(result))
	world.free();quit()
