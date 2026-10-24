extends SceneTree
const Wildlife=preload("res://wildlife.gd")
const WildlifeData=preload("res://wildlife_data.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]

func _initialize()->void:call_deferred("_run")

func check(condition:bool,label:String)->void:
	checks+=1
	if not condition:
		failures.append(label)
		if failures.size()<25:push_error("FAIL "+label)

func _run()->void:
	var game:Variant=load("res://main.tscn").instantiate()
	game.resource_seed=157
	game.night=3
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var moved:Dictionary={}
	var max_count:=0
	for seed_value in [16,157,516]:
		var sim:=Wildlife.new()
		sim.setup(game,seed_value)
		for active_period in ["day","dusk","night","day"]:
			game.phase=active_period
			sim.update(game,.016,active_period)
			# v0.3.0: more habitats, larger day caps (6 rabbits, 5 deer, 3 foxes).
			var expected:=14 if active_period=="day" else (3 if active_period=="dusk" else 4)
			check(sim.animals.size()==expected,"all habitat caps populate seed %d %s"%[seed_value,active_period])
			max_count=maxi(max_count,sim.animals.size())
			var starts:Dictionary={}
			for animal in sim.animals:starts[int(animal.uid)]=animal.p
			for tick in range(120):
				sim.update(game,.05,active_period)
				for animal in sim.animals:
					check(WildlifeData.active(str(animal.species),active_period),"no wrong-time species")
					check(sim._ground_clear(game,animal,animal.p),"actual species capsule avoids all world solids")
					var shape:PackedVector2Array=sim.footprint(animal,animal.p)
					for other in sim.animals:
						if int(other.uid)<=int(animal.uid):continue
						check(not Geometry.polygons_overlap(shape,sim.footprint(other,other.p)),"animal feet remain separated")
			for animal in sim.animals:
				if animal.p.distance_to(starts[int(animal.uid)])>3.0:moved[animal.species]=true
			print("WILDLIFE_WORLD phase=",active_period," seed=",seed_value," count=",sim.animals.size())
	for species in WildlifeData.SPECIES_ORDER:check(moved.has(species),"actual map "+species+" changes location while walking")
	print("WILDLIFE_WORLD_RESULT checks=",checks," failures=",failures.size()," max_live=",max_count," moved_species=",moved.keys())
	game.queue_free()
	quit(0 if failures.is_empty() else 1)
