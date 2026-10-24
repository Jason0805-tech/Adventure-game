extends SceneTree
# Renders the real game (gl_compatibility, like the web build) at given spots
# and saves screenshots. SPOTS="x,y;x,y" OUT=dir
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var g: Variant = load("res://main.tscn").instantiate()
	g.resource_seed = 164
	root.add_child(g)
	await process_frame
	g.wildlife.animals.clear()
	if OS.get_environment("COLLIDE") == "1": g.show_collision = true
	if OS.get_environment("SANITY") != "": g.sanity = float(OS.get_environment("SANITY"))
	if OS.get_environment("FULLNESS") != "": g.fullness = int(OS.get_environment("FULLNESS"))
	if OS.get_environment("HEALTH") != "": g.health = float(OS.get_environment("HEALTH"))
	var spots: PackedStringArray = OS.get_environment("SPOTS").split(";")
	var out: String = OS.get_environment("OUT")
	var n := 0
	for spot in spots:
		var xy := spot.split(",")
		g.player = Vector2(float(xy[0]), float(xy[1]))
		if not g.static_walkable(g.player): g.release_player()
		if OS.get_environment("MAP") == "1": g.map_view.reveal(g.player, 5000.0); g.map_open = true
		for i in range(8): await process_frame
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/shot_%d.png" % [out, n]); n += 1
	print("SHOTS ", n)
	quit()
