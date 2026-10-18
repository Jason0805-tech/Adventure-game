extends SceneTree
# Runs the real scene and its native _draw, with synthetic Godot touch events.
# This is not browser/Safari or a human device playthrough.
class Scene:
	extends "res://main.gd"
	var all_ui_buttons: Array = []
	var actual_draws := 0
	var draw_usec := 0
	func ui_button(rect: Rect2, text: String, id: String, enabled: bool = true) -> void:
		all_ui_buttons.append({"rect":rect,"id":id,"enabled":enabled})
		super.ui_button(rect,text,id,enabled)
	func _draw() -> void:
		all_ui_buttons.clear()
		var started := Time.get_ticks_usec()
		super._draw()
		draw_usec += Time.get_ticks_usec() - started
		actual_draws += 1
var game: Variant
var checks := 0
var failures: Array[String] = []
func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description); push_error(description)
func event(index: int, point: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index=index;e.position=point;e.pressed=pressed
	return e
func tap(point: Vector2, index: int = 3) -> void:
	game._input(event(index,point,true))
	game._input(event(index,point,false))
func frame() -> void:
	game.queue_redraw()
	await process_frame
	await process_frame
func button(id: String) -> Dictionary:
	for b in game.all_ui_buttons:
		if b.id == id: return b
	return {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size=Vector2i(1518,720)
	root.content_scale_size=Vector2i(1518,720)
	game=Scene.new()
	game.resource_seed=163
	root.add_child(game)
	game.set_process(false)
	game.dialog="";game.inventory=false;game.crafting=false;game.paused=false;game.browser_suspended=false
	game.phase="day";game.message_time=0
	check(game.mobile.enabled,"--touch enables real mobile input")
	check(game.get_viewport_rect().size==Vector2(1518,720),"real landscape virtual viewport")
	game.mobile.css_height=320
	await frame()
	check(game.mobile.hit_regions.heal.size.x==99,"real draw uses Safari CSS-height target adaptation")
	check(game.actual_draws>0,"actual scene _draw submitted native Canvas commands")
	# Deterministic bag contents isolate tap/quick-bind from random world resources.
	game.bag=load("res://inventory.gd").new()
	game.bag.add("stone_axe",1);game.bag.add("medicine",2)
	game.hotbar.assign([-1,-1,-1,-1,-1,-1])
	game.inventory=true
	await frame()
	var first: Rect2=game.bag_slot_rect(0)
	var quick: Rect2=game.bag_hotbar_rect(4)
	var original: Dictionary=game.bag.slots[0].duplicate(true)
	tap(first.get_center())
	check(game.selected_slot==0 and game.drag_slot==-1,"tap selects a bag item without leaving a drag")
	check(game.bag.slots[0]==original,"tap does not rearrange or consume selected item")
	tap(quick.get_center())
	check(game.hotbar[4]==int(original.uid),"tap a quick slot assigns selected item by UID")
	check(game.action.is_empty() and game.bag.item_by_uid(int(original.uid))==original,"binding a quick slot equips without auto-use or durability cost")
	for i in range(24):
		var r: Rect2=game.bag_slot_rect(i)
		check(r.size.x>=99 and r.size.y>=99,"bag touch target99px at Safari320height")
	# A real touch drag rearranges; a tap does not accidentally swap slots.
	var start: Vector2=game.bag_slot_rect(0).get_center()
	var finish: Vector2=game.bag_slot_rect(2).get_center()
	game._input(event(4,start,true))
	var drag:=InputEventScreenDrag.new();drag.index=4;drag.position=finish;drag.relative=finish-start
	game._input(drag)
	game._input(event(4,finish,false))
	check(game.bag.slots[2].get("uid",-1)==original.uid and game.bag.slots[0].is_empty(),"real drag moves a bag stack")
	check(game.hotbar[4]==int(original.uid),"rearranging preserves quick-slot UID")
	# Field crafting has four large rows and usable page controls.
	game.inventory=false;game.crafting=true;game.crafting_station=-1;game.crafting_page=0
	for id in ["branch","rock","fiber","rope"]:game.bag.add(id,30)
	await frame()
	var recipes: Array=game.visible_recipes()
	var rows: Array=game.all_ui_buttons.filter(func(b):return str(b.id).begins_with("craft_"))
	check(rows.size()==mini(4,recipes.size()),"crafting renders four recipes per page")
	for b in rows:
		check(b.rect.size.y>=99 and b.rect.size.x>=99,"craft recipe minimum99px touch target")
	var pages:=maxi(1,ceili(recipes.size()/4.0))
	if pages>1:
		var next:=button("next_page")
		check(not next.is_empty() and next.enabled,"next crafting page enabled")
		tap(next.rect.get_center())
		await frame()
		check(game.crafting_page==1,"native touch advances crafting page")
		rows=game.all_ui_buttons.filter(func(b):return str(b.id).begins_with("craft_"))
		check(rows.size()==mini(4,recipes.size()-4),"second page contains remaining field recipes")
		var previous:=button("previous_page")
		tap(previous.rect.get_center())
		await frame()
		check(game.crafting_page==0,"native touch returns to first crafting page")
	rows=game.all_ui_buttons.filter(func(b):return str(b.id).begins_with("craft_") and b.enabled)
	check(not rows.is_empty(),"funded field recipes can be crafted")
	if not rows.is_empty():
		var b: Dictionary=rows[0]
		var index:=int(str(b.id).trim_prefix("craft_"))
		var id: String=game.Data.RECIPES[index].id
		var old_count: int=game.bag.count(id)
		tap(b.rect.get_center())
		check(game.bag.count(id)>old_count,"real touch crafting creates its promised item")
	# Exercise real native drawing of each modal and responsive control layout.
	game.crafting=false;game.inventory=false;game.dialog="";game.paused=true
	await frame()
	check(not button("resume").is_empty(),"native pause panel has large Resume target")
	tap(button("resume").rect.get_center())
	check(not game.paused,"native Resume touch closes pause")
	game.mobile.css_height=390
	await frame()
	check(game.mobile.hit_regions.heal.size.x==82,"full-height Safari uses82px targets")
	root.size=Vector2i(1080,720);root.content_scale_size=Vector2i(1080,720)
	await frame()
	check(game.mobile.hit_regions.slot_0.position.y==160,"narrow landscape relocates hotbar below HUD")
	check(game.mobile.hit_regions.slot_0.end.x<game.mobile.hit_regions.slot_1.position.x,"narrow toolbar keeps slots distinct")
	var result: Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty(),"actual_native_draws":game.actual_draws,"draw_command_usec":game.draw_usec,"source_hashes":{"main.gd":FileAccess.get_sha256("res://main.gd"),"mobile_controls.gd":FileAccess.get_sha256("res://mobile_controls.gd"),"mobile_ui.gd":FileAccess.get_sha256("res://mobile_ui.gd")},"scope":"Actual native Godot scene and synthetic ScreenTouch/Drag; not browser/Safari/device QA"}
	var args:=OS.get_cmdline_user_args()
	var output: String=""
	for i in range(args.size()-1):
		if args[i]=="--result":output=args[i+1]
	if not output.is_empty():
		var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"))
	print("MOBILE_UI_INTEGRATION ",JSON.stringify(result))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
