extends "res://../../tests/0.1.5.9/test_all_model_fronts.gd"
# Preserve all three pillar/arch contact captures after the coherence fix,
# including the prior failing center column even when it now passes.
func measure(label:String,_save:bool=false)->void:super.measure(label,true)
func run()->void:
	game=load(OUT+"snapshot_game.gd").new();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(50,1450);game.npc_position=Vector2(90,1450);game.message_time=0;game.show_collision=false;game.day_time=30
	full_world=game.solid_bodies.duplicate(true)
	test_entry(game.scenery_entry("gate",game.gate+Vector2(0,30)),"live",true)
	var summary:Dictionary={"version":"0.1.5.9","checks":checks,"failures":failures,"results":results,"method":"Same local front-contact criteria and actual Canvas alpha audit as all-model suite; all three gate contacts retain fresh corrected captures."}
	var file:=FileAccess.open(OUT+"gate-front-visibility-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("GATE_FRONT_VISIBILITY ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
