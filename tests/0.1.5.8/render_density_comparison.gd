extends SceneTree

const BASE = "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.8/density-renders"

class ComparisonCanvas extends Node2D:
	var images: Dictionary = {}
	var meta: Dictionary = {}
	var font: Font = ThemeDB.fallback_font
	var placements: Array = [
		["cabin", Vector2(151,310)], ["prop_1",Vector2(292,323)],
		["bench",Vector2(265,230)], ["tree_0",Vector2(38,405)],
		["tree_2",Vector2(524,463)], ["shrub_2",Vector2(453,388)],
		["ore_0",Vector2(402,334)], ["stump_0",Vector2(312,447)],
		["resource_branch_0",Vector2(203,393)], ["resource_branch_1",Vector2(246,417)],
		["resource_rock_0",Vector2(376,425)], ["resource_rock_1",Vector2(391,453)],
		["resource_rope_0",Vector2(164,450)], ["resource_rope_1",Vector2(174,400)]
	]

	func load_images() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		meta = JSON.parse_string(FileAccess.get_file_as_string(BASE + "/density-metadata.json")).objects
		for key in meta:
			for state in ["before", "after"]:
				var image: Image = Image.load_from_file(BASE + "/" + key + "-" + state + ".png")
				image.fix_alpha_edges()
				image.generate_mipmaps()
				images[key + "-" + state] = ImageTexture.create_from_image(image)

	func paint_panel(origin: Vector2, state: String) -> void:
		var texture: Texture2D = images["meadow-" + state]
		var ratio: Vector2 = Vector2(texture.get_width(),texture.get_height()) / Vector2(2200,1500)
		draw_texture_rect_region(texture, Rect2(origin,Vector2(590,480)), Rect2(Vector2(170,430)*ratio,Vector2(590,480)*ratio))
		var pond: Texture2D = images["pond_1-" + state]
		draw_texture_rect(pond,Rect2(origin + Vector2(350,12),Vector2(220,150)),false)
		for placement in placements:
			var key: String = placement[0]
			var entry: Dictionary = meta[key]
			var size: Vector2 = Vector2(float(entry.world[0]),float(entry.world[1]))
			var scale: float = size.y / float(entry.source[1])
			var anchor: Vector2 = Vector2(float(entry.anchor[0]),float(entry.anchor[1])) * scale
			draw_texture_rect(images[key+"-"+state],Rect2(origin + placement[1] - anchor,size),false)
		draw_rect(Rect2(origin,Vector2(590,480)),Color("395944"),false,1)

	func _draw() -> void:
		draw_rect(Rect2(0,0,1246,670), Color("14251f"))
		draw_string(font,Vector2(22,33),"Same game sprites and physical sizes · shared 2 world units per texel",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("efe5c7"))
		draw_string(font,Vector2(22,67),"BEFORE · source grain varies by object",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("e6dfc7"))
		draw_string(font,Vector2(636,67),"AFTER · broad strokes share the ground sampling scale",HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("e6dfc7"))
		paint_panel(Vector2(22,82),"before")
		paint_panel(Vector2(636,82),"after")
		draw_string(font,Vector2(22,590),"Cabin 222 world high: 498 → 111 texels     Workbench 82: 378 → 41 texels",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e6dfc7"))
		draw_string(font,Vector2(22,619),"Branches / grass 38 world high: 257–336 → 19 texels     Meadow 2200 × 1500: 1100 × 750 texels",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("e6dfc7"))
		draw_string(font,Vector2(22,648),"Original alpha, object silhouettes, world rectangles and foot anchors stay unchanged. Linear display filtering.",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("a9c2a9"))

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1246,670)
	root.title = "Forest Wanderer 0.1.5.8 · paint density comparison"
	var canvas := ComparisonCanvas.new()
	canvas.load_images()
	root.add_child(canvas)
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	assert(shot.get_width() == 1246 and shot.get_height() == 670)
	shot.save_png(BASE + "/paint-density-before-after.png")
	print("PAINT_DENSITY_NATIVE_COMPARISON_SAVED 1246x670 world_scale=1:1")
	quit(0)
