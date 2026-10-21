extends SceneTree
var world: Variant
var stage := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	world = load("res://main.gd").new()
	root.add_child(world)
	world.set_process(false)
	world.phase = "night"
	world.night_elapsed = 40.0
	world.day_time = 180.0
	world.bag.add("torch",1)
	var index: int = world.bag.first("torch")
	world.torch_uid=int(world.bag.slots[index].uid)
	world.torch_fuel=120.0
	world.torch_lit=true
	world.queue_redraw()
	await process_frame
	await process_frame
	world.torch_lit=false
	world.player=Vector2(1100,1100)
	world.solid_bodies.clear()
	world.wildlife.animals.clear()
	world.wildlife.animals.append({"uid":999,"species":"wolf","p":world.player+Vector2(120,0),"facing":Vector2.DOWN,"moving":false,"walk":0.0,"state":"idle","age":5.0,"hitflash":0.0,"hp":65.0,"timer":0.5})
	var eyes:Array=world.lighting.eye_entries(world)
	assert(eyes.size()==2,"Actual wolf art has two registered eyes during dark draw")
	world.queue_redraw()
	await process_frame
	await process_frame
	world.phase="dusk";world.phase_time=3;world.queue_redraw()
	await process_frame
	await process_frame
	world.phase="day";world.day_time=0;world.queue_redraw()
	await process_frame
	await process_frame
	print("NATIVE_LIGHTING_DRAW_READY torch/dark-eyes/dusk/dawn")
	world.queue_free()
	quit()
