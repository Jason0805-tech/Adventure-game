extends SceneTree
# Geometry is captured from the real mobile_ui draw methods, not duplicate CSS.
class Inspector:
	extends "res://main.gd"
	var panels: Array[Rect2] = []
	var all_ui_buttons: Array = []
	var native_ui_draws := 0
	func paper_panel(rect: Rect2, fill: Color, radius: int = 12) -> void:
		panels.append(rect)
		super.paper_panel(rect,fill,radius)
	func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
		all_ui_buttons.append({"rect":rect,"id":id,"enabled":enabled})
		super.ui_button(rect,text,id,enabled)
	func _draw() -> void:
		panels.clear();all_ui_buttons.clear()
		draw_survival_ui(get_viewport_rect().size)
		native_ui_draws+=1
var game: Variant
var checks := 0
var failures: Array[String] = []
var cases: Array = []
func check(value: bool, description: String) -> void:
	checks+=1
	if not value:failures.append(description);push_error(description)
func frame() -> void:
	game.queue_redraw();await process_frame;await process_frame
func rect_data(rect: Rect2) -> Array:
	return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
func inspect_targets(targets: Dictionary, css_height: float, context: String) -> void:
	var keys: Array=targets.keys()
	for i in range(keys.size()):
		var rect: Rect2=targets[keys[i]]
		check(rect.size.x*css_height/720.0>=43.999 and rect.size.y*css_height/720.0>=43.999,context+"44CSS target "+str(keys[i]))
		check(Rect2(Vector2.ZERO,game.get_viewport_rect().size).encloses(rect),context+"target within screen "+str(keys[i]))
		for j in range(i+1,keys.size()):
			check(not rect.intersects(targets[keys[j]]),context+"no target overlap "+str(keys[i])+"/"+str(keys[j]))
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1518,720);root.content_scale_size=Vector2i(1518,720)
	game=Inspector.new();root.add_child(game);game.set_process(false)
	game.dialog="";game.paused=false;game.inventory=false;game.crafting=false;game.browser_suspended=false
	game.message="Placement audit: walk, gather, craft, and survive three nights."
	game.message_time=100;game.phase="day"
	for css_height in [320.0,390.0]:
		for width in [960,1080,1319,1320,1518,1920]:
			root.size=Vector2i(width,720);root.content_scale_size=Vector2i(width,720)
			game.mobile.css_height=css_height
			var context: String=str(width)+"virtual/"+str(css_height)+"CSS "
			game.inventory=false;game.crafting=false
			await frame()
			var toast: Rect2=game.panels.back()
			var weather: Rect2=game.panels[-2]
			check(toast.size.y==94,context+"recorded actual toast panel")
			var regions: Dictionary=game.mobile.hit_regions
			inspect_targets(regions,css_height,context+"exploration ")
			for name in regions:
				check(not toast.intersects(regions[name]),context+"toast clears "+str(name))
				check(not weather.intersects(regions[name]),context+"weather clears "+str(name))
			check(not toast.intersects(weather),context+"toast and weather separated")
			check(toast.position.y>=124,context+"toast clears survival HUD")
			cases.append({"width":width,"css_height":css_height,"toast":rect_data(toast),"weather":rect_data(weather),"slot_0":rect_data(regions.slot_0),"minimum_target":game.mobile._layout.min_target})
			game.inventory=true
			await frame()
			var bag_targets: Dictionary={}
			for i in range(24):bag_targets["bag_"+str(i)]=game.bag_slot_rect(i)
			for i in range(6):bag_targets["quick_"+str(i)]=game.bag_hotbar_rect(i)
			for b in game.all_ui_buttons:bag_targets[b.id]=b.rect
			inspect_targets(bag_targets,css_height,context+"backpack ")
			game.inventory=false;game.crafting=true;game.crafting_page=0
			await frame()
			var craft_targets: Dictionary={}
			for b in game.all_ui_buttons:craft_targets[b.id]=b.rect
			inspect_targets(craft_targets,css_height,context+"crafting ")
	var result: Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"native_ui_draws":game.native_ui_draws,"cases":cases,"source_hashes":{"main.gd":FileAccess.get_sha256("res://main.gd"),"mobile_controls.gd":FileAccess.get_sha256("res://mobile_controls.gd"),"mobile_ui.gd":FileAccess.get_sha256("res://mobile_ui.gd")},"scope":"Real mobile UI native Canvas geometry: all controls, toast and weather; not a browser/device visual review."}
	var args:=OS.get_cmdline_user_args()
	for i in range(args.size()-1):
		if args[i]=="--result":
			var f:=FileAccess.open(args[i+1],FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"))
	print("MOBILE_PLACEMENT_AUDIT ",JSON.stringify({"passed":result.passed,"checks":checks,"failures":failures,"native_ui_draws":game.native_ui_draws}))
	game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
