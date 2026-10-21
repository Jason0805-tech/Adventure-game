extends SceneTree
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func new_wolf(g:Variant,p:Vector2)->Dictionary:
	g.wildlife._spawn_one(g,"wolf")
	var a:Dictionary=g.wildlife.animals.back();a.p=p;a.home=p;a.age=20;a.state="idle";a.timer=5.0
	return a
func run()->void:
	var g:Variant=load("res://main.tscn").instantiate();g.resource_seed=164;root.add_child(g);g.set_process(false);await process_frame
	g.player=Vector2(1000,760);g.phase="night";g.night_elapsed=30;g.fullness=100;g.sanity=100;g.wildlife.animals.clear()
	var wolf:Dictionary=new_wolf(g,Vector2(1100,760))
	g.survival.update(g,.05);check(g.sanity>99,"idle proximity is not a dangerous encounter")
	wolf.state="chase";g.sanity=100;g.survival.update(g,.05)
	check(absf(g.sanity-94.9825)<.001,"first dangerous encounter loses5 plus ordinary darkness")
	g.bag.add("torch",1);g.torch_uid=int(g.bag.slots[g.bag.first("torch")].uid);g.torch_lit=true;g.torch_fuel=120
	var before:float=g.sanity
	for i in range(100):g.survival.update(g,.05)
	check(g.sanity==before,"same encounter cannot drain sanity every frame")
	var second:Dictionary=new_wolf(g,Vector2(1000,900));second.state="chase";g.survival.update(g,.05)
	check(g.sanity==before,"pack shares encounter cooldown")
	g.survival.encounter_cooldown=0;var third:Dictionary=new_wolf(g,Vector2(850,760));third.state="chase";g.survival.update(g,.05)
	check(g.sanity==before-5,"new encounter after cooldown can create pressure")
	g.wildlife.animals.clear();g.sanity=69.9;g.survival.illusion_in=0;g._process(0.0)
	g.survival.update(g,.05)
	check(not g.survival.illusion.is_empty() and g.survival.illusion_in>=26,"unstable sanity creates a rare registered environment illusion")
	g.sanity=20;g.survival.illusion_in=0;g.survival.update(g,.05)
	check(g.survival.illusion_in>=12 and g.survival.illusion_in<=20,"critical illusions use a more frequent bounded interval")
	g.sanity=70;g.survival.update(g,.05);check(g.survival.illusion.is_empty(),"normal sanity clears negative visual effects")
	g.wildlife.animals.clear();g.fullness=5;g.sanity=80
	for i in range(200):g.survival.update(g,.05)
	check(absf(g.sanity-79)<.001,"severe hunger drains .10/sec even with torch")
	g.torch_lit=false;g.fullness=100;g.player=Vector2(360,760);g.sanity=60
	var danger:Dictionary=new_wolf(g,Vector2(400,800));danger.state="windup"
	for i in range(100):g.survival.update(g,.05)
	check(not g.survival.resting and g.sanity<=60,"nearby predator prevents camp rest recovery")
	g.wildlife.animals.clear();g.sanity=20;g.fullness=100
	g.survival.update(g,.05);check(not g.wildlife.has_shadow(),"illuminated camp never summons a hostile shadow")
	g.player=Vector2(1200,760);g.survival.shadow_cooldown=0;g.survival.shadow_retry=0
	g.survival.update(g,.05);check(g.wildlife.has_shadow(),"shadow summoned in real dark world")
	var shadow:Dictionary={}
	for a in g.wildlife.animals:
		if a.get("shadow",false):shadow=a
	if not shadow.is_empty():
		shadow.p=g.player+Vector2(50,0);shadow.facing=Vector2.LEFT;shadow.age=10
		var result:Dictionary=g.wildlife.attack(g,g.player,Vector2.RIGHT,48,68,.2)
		check(result.hits==1 and not g.wildlife.has_shadow(),"real shadow is defeatable by existing weapon contact")
		check(g.wildlife.kills.get("wolf",0)==0,"shadow does not create real wildlife kill rewards")
	g.bag.add("crystal",1);g.health=50
	check(g.wildlife_damage(22,"bear")==0 and g.health==50 and g.bag.count("crystal")==0,"finite ward consumes once and blocks actual hit")
	check(g.wildlife_damage(12,"wolf")==12 and g.health==38,"no ward immunity after consumption")
	g.bag.add("fish",1);g.fullness=99;g.sanity=50
	g.auto_equip(int(g.bag.slots[g.bag.first("fish")].uid));g.use_selected()
	check(g.fullness==100 and absf(g.sanity-50.16)<.001,"one-point hunger top-up cannot farm full fish sanity reward")
	g.phase="day";g.player=g.npc_position+Vector2(35,0);g.interaction_cooldown=0;g.action.clear();g.dialog=""
	var f_before:int=g.bag.count("fish");var m_before:int=g.bag.count("medicine");var w_before:int=g.bag.count("crystal")
	g.interact()
	check(g.scout_rewarded and g.bag.count("fish")==f_before+2 and g.bag.count("medicine")==m_before+1 and g.bag.count("crystal")==w_before+1,"real first scout conversation rewards exploration supplies")
	g.dialog="";g.interact()
	check(g.bag.count("fish")==f_before+2 and g.bag.count("medicine")==m_before+1 and g.bag.count("crystal")==w_before+1,"repeated conversation cannot duplicate scout supplies")
	g.dialog=""
	# Full backpack and repair/craft failures remain atomic.
	while g.bag.used_slots()<24:g.bag.add("wood_knife",1)
	check(g.bag.used_slots()==24 and g.bag.validate(),"full inventory remains valid")
	var slots:Array=g.bag.slots.duplicate(true);g.craft_recipe(0)
	check(slots==g.bag.slots,"failed crafting consumes nothing")
	g.give_item("fishing_rod",1,g.player+Vector2(25,0));check(g.items.back().get("dropped",false) and g.items.back().kind=="fishing_rod","full bag keeps unstackable overflow loot on ground")
	# Portrait and browser suspension freeze the complete state through real frame gate.
	g.mobile.enabled=true;root.size=Vector2i(720,1100);await process_frame
	var snapshot:Array=[g.elapsed,g.sanity,g.fullness,g.night_elapsed,g.survival.effect_time,g.npc_states.duplicate(true)]
	g._process(.05);g.survival.update(g,10)
	check(snapshot==[g.elapsed,g.sanity,g.fullness,g.night_elapsed,g.survival.effect_time,g.npc_states],"portrait pause freezes new and existing clocks")
	root.size=Vector2i(1100,720);g.mobile.enabled=false;await process_frame
	check(g.simulation_running(),"landscape restoration resumes normal simulation")
	var report:Dictionary={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open(ProjectSettings.globalize_path("res://../edge-results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("EDGE_RESULTS ",JSON.stringify(report));g.queue_free();quit(0 if failures.is_empty() else 1)
