extends "res://main.gd"
# Render-only fixture. Not part of the delivered game; explicitly staged.
func _ready() -> void:
	resource_seed=164
	super._ready()
	phase="night";night=3;night_elapsed=34.0;phase_time=34.0
	player=Vector2(1000,760);health=78;fullness=18;sanity=18
	bag.add("amazing_sword",1);auto_equip(int(bag.slots[bag.first("amazing_sword")].uid))
	wildlife.animals.clear();wildlife.period="night"
	wildlife._spawn_one(self,"bear")
	var bear:Dictionary=wildlife.animals.back()
	bear.p=player+Vector2(145,25);bear.home=bear.p;bear.age=20;bear.facing=Vector2.LEFT
	bear.state="charge_warn";bear.timer=1.05;bear.warning_duration=1.05;bear.locked_aim=player
	wildlife._spawn_one(self,"wolf",false)
	var shadow:Dictionary=wildlife.animals.back()
	shadow.shadow=true;shadow.hp=42;shadow.age=20;shadow.p=player+Vector2(-100,18);shadow.facing=Vector2.RIGHT;shadow.state="windup";shadow.timer=.65;shadow.warning_duration=.65
	survival.effect_time=5;survival.illusion_age=1.4
	message="Staged QA: CRITICAL sanity, real shadow, bear charge telegraph."
	message_time=20
	_process(0.0)
	set_process(false)
	queue_redraw()
	print("STAGED_VISUAL_QA native-art, critical sanity, shadow and charge overlay")
