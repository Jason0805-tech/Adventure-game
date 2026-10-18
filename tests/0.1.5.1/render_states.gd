extends SceneTree
func _initialize() -> void:
	call_deferred("check_states")
func check_states() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.font = ThemeDB.fallback_font
	for state in ["day", "crafting", "inventory", "dialog", "paused", "dusk", "choice", "encounter", "result", "lost", "won"]:
		scene.inventory = state == "inventory"
		scene.crafting = state == "crafting"
		scene.paused = state == "paused"
		scene.dialog = "Rowan - Camp guide\n\nSurvive three nights." if state == "dialog" else ""
		scene.phase = "day" if state in ["crafting", "inventory", "dialog", "paused"] else state
		scene.won = state == "won"
		scene.lost = state == "lost"
		scene.queue_redraw()
		await process_frame
		await process_frame
		print("UI_STATE_OK ", state)
	scene.queue_free()
	quit()
