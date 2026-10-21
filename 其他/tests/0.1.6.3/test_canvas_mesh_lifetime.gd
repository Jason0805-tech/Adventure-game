extends SceneTree
const Lighting=preload("res://world_lighting.gd")
var checks:=0
var failures:Array[String]=[]
class WeakCanvas extends RefCounted:
	var phase:="day"
	var day_time:=0.0
	var day_duration:=180.0
	var phase_time:=0.0
	var dusk_duration:=6.0
	var night_elapsed:=0.0
	var night_duration:=90.0
	var camera:=Vector2.ZERO
	var player:=Vector2(360,760)
	var torch_lit:=false
	var torch_fuel:=0.0
	var wildlife:Variant=null
	var weak_meshes:Array[WeakRef]=[]
	var size:=Vector2(844,390)
	func get_viewport_rect()->Rect2:return Rect2(Vector2.ZERO,size)
	func draw_rect(_r:Rect2,_c:Color,_f:bool=true,_w:float=-1,_a:bool=false)->void:pass
	func draw_mesh(value:Mesh,_texture:Texture2D=null,_transform:Transform2D=Transform2D.IDENTITY,_color:Color=Color.WHITE)->void:weak_meshes.append(weakref(value))
class CaptureCanvas extends WeakCanvas:
	var meshes:Array[ArrayMesh]=[]
	func record_draw_mesh(value:ArrayMesh)->void:meshes.append(value)
func _initialize()->void:call_deferred("_run")
func check(ok:bool,note:String)->void:
	checks+=1
	if not ok:failures.append(note);push_error(note)
func _run()->void:
	var light=Lighting.new()
	var world=WeakCanvas.new()
	light.draw(world)
	check(world.weak_meshes.size()==1,"Dawn submits one lighting mesh")
	check(world.weak_meshes[0].get_ref()!=null,"Canvas mesh remains alive after draw() returns")
	var previous:int=0
	if world.weak_meshes[0].get_ref()!=null:previous=world.weak_meshes[0].get_ref().get_instance_id()
	for cycle in range(24):
		world.phase="night" if cycle%3==0 else ("dusk" if cycle%3==1 else "day")
		world.day_time=170.0
		world.phase_time=float(cycle%7)
		world.night_elapsed=float(cycle*3)
		world.torch_lit=cycle%2==0;world.torch_fuel=30.0
		if cycle==12:world.size=Vector2(1100,720)
		var expected:ArrayMesh=light.darkness_mesh(world,world.size)
		light.draw(world)
		var actual:ArrayMesh=world.weak_meshes.back().get_ref()
		check(actual!=null,"Runtime mesh retained frame "+str(cycle))
		if actual==null:continue
		check(actual.get_instance_id()==previous,"Runtime mesh identity reused across phase/resize "+str(cycle))
		var a:Array=actual.surface_get_arrays(0);var b:Array=expected.surface_get_arrays(0)
		check(a[Mesh.ARRAY_VERTEX]==b[Mesh.ARRAY_VERTEX],"Native lighting vertices unchanged "+str(cycle))
		check(a[Mesh.ARRAY_COLOR]==b[Mesh.ARRAY_COLOR],"Dawn/dusk/night/torch exposure unchanged "+str(cycle))
		check(a[Mesh.ARRAY_INDEX]==b[Mesh.ARRAY_INDEX],"Lighting triangle topology unchanged "+str(cycle))
	var capture=CaptureCanvas.new()
	light.draw(capture)
	capture.phase="night";capture.night_elapsed=45
	light.draw(capture)
	check(capture.meshes.size()==2,"Capture retains two separate lighting snapshots")
	check(capture.meshes[0]!=capture.meshes[1],"Capture snapshot identities remain independent")
	check(capture.meshes[0].surface_get_arrays(0)[Mesh.ARRAY_COLOR]!=capture.meshes[1].surface_get_arrays(0)[Mesh.ARRAY_COLOR],"Captured dawn and midnight colors remain distinct")
	print("CANVAS_MESH_LIFETIME ",checks," checks failures=",failures.size())
	quit(0 if failures.is_empty()else 1)
