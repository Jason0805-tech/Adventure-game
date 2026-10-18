extends "res://../../tests/0.1.5.9/test_all_model_fronts.gd"
func measure(label:String,_save:bool=false)->void:super.measure(label,true)
func run()->void:
	game=load(OUT+"snapshot_game.gd").new();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(50,1450);game.npc_position=Vector2(90,1450);game.message_time=0;game.show_collision=false;game.day_time=30
	full_world=game.solid_bodies.duplicate(true)
	var stone:int=0
	for body in full_world:
		if body.kind!="bank_rock":continue
		var entry:Dictionary={"kind":body.kind,"p":body.p,"index":body.index,"id":body.id,"profile":body.profile}
		test_entry(entry,"stone"+str(stone),false);stone+=1
	var summary:Dictionary={"version":"0.1.5.9","checks":checks,"failures":failures,"stones":stone,"results":results,"method":"One fresh actual Canvas alpha-tested local-front contact and capture for each of all17distinct bankstoneIDs; supplements443broadfront checks which alreadycover3columnsperstone."}
	var file:=FileAccess.open(OUT+"all-bank-stone-front-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("BANK_STONE_FRONT_VISIBILITY ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
