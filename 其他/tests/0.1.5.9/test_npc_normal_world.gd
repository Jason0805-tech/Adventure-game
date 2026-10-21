extends "res://../../tests/0.1.5.9/walk_all_models.gd"
func run()->void:
	game=load("res://main.tscn").instantiate();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	all_world_bodies=game.solid_bodies.duplicate(true)
	simulate_npcs()
	var summary:Dictionary={"version":"0.1.5.9","state":"normal live trees, resources and full ore","checks":checks,"failures":failures,"failure_labels":failures_list}
	var file:=FileAccess.open(OUT+"npc-normal-world-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("NPC_NORMAL_WORLD_RESULTS ",JSON.stringify(summary))
	game.queue_free();quit(0 if failures==0 else 1)
