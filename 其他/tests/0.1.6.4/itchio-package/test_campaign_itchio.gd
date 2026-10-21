extends SceneTree
var checks:=0
var failures:Array[String]=[]
var runs:Array=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func equip(g:Variant,id:String)->void:
	var index:int=g.bag.first(id)
	if index>=0:g.auto_equip(int(g.bag.slots[index].uid))
func run()->void:
	for seed_value in [164,271,407]:
		for prepared in [true,false]:
			var g:Variant=load("res://main.tscn").instantiate();g.resource_seed=seed_value
			root.add_child(g);g.set_process(false);await process_frame
			var rng:=RandomNumberGenerator.new();rng.seed=seed_value
			var healing_used:=0;var attacks:=0;var meal_used:=0;var reactions:=0.0;var elapsed_seconds:=0.0;var min_health:=100.0;var encounters:=0
			# Stocked-camp scenario, not a claimed gathering playthrough: materials
			# are supplied here; all recipes, costs, item use and combat are production.
			if prepared:
				for id in ["branch","rock","rope"]:g.bag.add(id,18)
				g.bag.add("ore",6);g.bag.add("fish",3);g.bag.add("medicine",2)
				g.player=Vector2(620,760);g.crafting_station=1
				g.craft_recipe(7);g.craft_recipe(9)
				for i in range(3):g.craft_recipe(11)
				g.craft_recipe(10);g.torch_lit=false
				equip(g,"amazing_sword")
				check(g.bag.count("amazing_sword")==1 and g.bag.count("crystal")==3,"actual advanced recipes paid seed"+str(seed_value))
				g.player=Vector2(360,760)
			for tick in range(18000):
				if g.phase=="result":g.next_day()
				if g.won or g.lost:break
				if prepared:
					if g.fullness<=50 and g.bag.count("fish")>0:
						equip(g,"fish");g.use_selected();meal_used+=1;equip(g,"amazing_sword")
					if g.health<=55 and g.bag.count("medicine")>0:g.use_medicine();healing_used+=1
					reactions-=.05
					if reactions<=0 and g.action.is_empty():
						reactions=rng.randf_range(.25,.55)
						var target:Dictionary={};var distance:=67.0
						for animal in g.wildlife.animals:
							if animal.species not in ["wolf","bear"]:continue
							var d:float=animal.p.distance_to(g.player)
							if d<distance:distance=d;target=animal
						if not target.is_empty() and rng.randf()>.15:
							g.facing=(target.p-g.player).normalized();g.use_selected();attacks+=1
				var old_sanity:float=g.sanity
				g._process(.05);elapsed_seconds+=.05;min_health=minf(min_health,g.health)
				if old_sanity-g.sanity>4:encounters+=1
			var report:Dictionary={"seed":seed_value,"prepared":prepared,"won":g.won,"lost":g.lost,"survived":g.survived,"health":g.health,"minimum_health":min_health,"fullness":g.fullness,"sanity":g.sanity,"elapsed_seconds":elapsed_seconds,"swings":attacks,"healing_used":healing_used,"meals_used":meal_used,"danger_encounters":encounters,"kills":g.wildlife.kills.duplicate(),"ward_remaining":g.bag.count("crystal")}
			runs.append(report);print("CAMPAIGN_RUN ",JSON.stringify(report))
			if prepared:check(g.won and g.survived==3,"stocked camp survives full unshortened three-night process seed"+str(seed_value))
			check(g.day_duration==180 and g.dusk_duration==6 and g.night_duration==90,"production timings preserved seed"+str(seed_value))
			g.queue_free();await process_frame
	for i in range(0,runs.size(),2):
		check(runs[i].health>runs[i+1].health or (runs[i].won and not runs[i+1].won),"preparation advantage paired seed"+str(runs[i].seed))
	var report:Dictionary={"checks":checks,"failures":failures,"runs":runs,"passed":failures.is_empty(),"scope":"Automated stationary camp scenarios; provisioned starting inventories explicitly, real recipes/combat/AI/production clocks. Not a manual or exploration playthrough."}
	FileAccess.open(ProjectSettings.globalize_path("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.4/itchio-package/campaign-results-rerun.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CAMPAIGN_RESULTS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
