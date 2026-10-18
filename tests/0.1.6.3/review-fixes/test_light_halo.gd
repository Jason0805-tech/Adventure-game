extends SceneTree
const Lighting=preload("res://world_lighting.gd")
class World extends RefCounted:
	var phase:="day"
	var day_time:=0.0
	var day_duration:=180.0
	var phase_time:=0.0
	var dusk_duration:=6.0
	var night_elapsed:=0.0
	var night_duration:=90.0
	var player:=Vector2(1800,1300)
	var torch_lit:=false
	var torch_fuel:=120.0
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message)
func _initialize()->void:
	var lighting:=Lighting.new()
	var world:=World.new()
	# Independent ground landmarks: the old lamp is visibly brighter at dawn
	# even while the player has no torch. No local light may lift daytime paint.
	for fraction in [0.0,0.04,0.16,0.45,0.68,0.95,1.0]:
		world.day_time=float(fraction)*world.day_duration
		var ambient:float=1.0-float(lighting.atmosphere(world).darkness)
		for lit in [false,true]:
			world.torch_lit=lit
			for point in [Vector2(455,725),Vector2(360,760),Vector2(455,830),Vector2(660,725),world.player,world.player+Vector2(20,0),Vector2(1200,300)]:
				check(absf(lighting.sample(world,point)-ambient)<0.00001,"Daylight halo at %s fraction %s torch %s"%[point,fraction,lit])
	world.phase="night";world.night_elapsed=35.0;world.torch_lit=false
	var ambient:float=1.0-float(lighting.atmosphere(world).darkness)
	for offset in [Vector2.ZERO,Vector2(8,0),Vector2(20,0),Vector2(100,0),Vector2(161,0)]:
		check(absf(lighting.sample(world,world.player+offset)-ambient)<0.00001,"Unlit player creates a free halo at %s"%offset)
	check(lighting.sample(world,Vector2(455,725))>0.9,"Night camp still provides real light")
	world.torch_lit=true
	check(lighting.sample(world,world.player+Vector2(40,0))>0.9,"Lit torch lights nearby ground")
	check(absf(lighting.sample(world,world.player+Vector2(161,0))-ambient)<0.00001,"Torch radius remains five metres")
	var previous:=lighting.sample(world,world.player)
	for i in range(1,171):
		var current:float=lighting.sample(world,world.player+Vector2(i,0))
		check(current<=previous+0.00001,"Torch falls off monotonically at %d"%i)
		check(absf(current-previous)<0.025,"No hard light-ring edge at %d"%i)
		previous=current
	# The lamp fades with ambient darkness rather than switching on at a phase boundary.
	world.torch_lit=false;world.phase="dusk"
	previous=lighting.sample(world,Vector2(580,725))
	for i in range(1,601):
		world.phase_time=i/100.0
		var current:float=lighting.sample(world,Vector2(580,725))
		check(absf(current-previous)<0.015,"Dusk light transition discontinuity at %d"%i)
		previous=current
	print(JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
