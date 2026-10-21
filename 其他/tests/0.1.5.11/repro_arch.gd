extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=load("res://main.tscn").instantiate();g.resource_seed=159;root.add_child(g);g.set_process(false)
	for c in g.get_children():c.set_process(false)
	g.npc_home=Vector2(90,90);g.npc_position=Vector2(140,90)
	var spec:Dictionary=g.model_spec("gate",g.gate+Vector2(0,30))
	print("GATE_RECT ",g.sprite_rect(spec.texture,spec.foot,spec.height)," foot ",spec.foot," feet ",g.feet_polygon(Vector2.ZERO))
	var rows:Array=[]
	for x in [1989.0,1991.0,1994.0]:
		for sign_y in [-1.0,1.0]:
			var start:=Vector2(x,360 if sign_y<0 else 155)
			g.player=start;g.move_player(Vector2(0,sign_y),205.0/g.SPEED)
			rows.append({"start":[start.x,start.y],"end":[g.player.x,g.player.y],"expected_y":start.y+sign_y*205,"blocked":absf(g.player.y-start.y-sign_y*205)>1})
	print("ARCH_REPRO ",JSON.stringify({"version":ProjectSettings.get_setting("application/config/name"),"rows":rows}))
	g.queue_free();quit()
