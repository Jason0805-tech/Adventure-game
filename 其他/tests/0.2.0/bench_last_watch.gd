# Last Watch benchmark: a dodging bot (2 medicine, 1 magic stone, no weapon, no torch) guards the beacon for nights 1-4, seeds 11/23/37.
extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var out:={}
	for night in [1,2,3,4]:
		var rows:=[]
		for seed in [11,23,37]:
			var g:Variant=load("res://main.tscn").instantiate();g.resource_seed=seed;root.add_child(g);g.set_process(false);await process_frame
			var b:Variant=g.beacon
			g.phase="night";g.night=night;g.night_elapsed=5.0;g.wildlife.animals.clear();g.wildlife.period=""
			b.stage="repaired";b.lens_found=true;b.rune_open=true;b.core_taken=true
			var guard:=Vector2.INF
			for r in [70.0,82.0,94.0,106.0]:
				for k in range(36):
					var q:Vector2=b.BEACON_POS+Vector2.RIGHT.rotated(TAU*k/36.0)*r
					if guard==Vector2.INF and g.walkable(q):
						g.player=q
						if str(g.nearest_target().get("kind",""))=="beacon":guard=q
			g.player=guard;g.bag.add("log",3);g.bag.add("medicine",2);g.bag.add("crystal",1);g.interaction_cooldown=0;g.interact()
			var dmg:=0.0;var t:=0.0
			while b.stage=="igniting" and t<70.0 and g.health>0:
				g.fullness=100;g.sanity=100
				if g.health<40 and g.bag.count("medicine")>0:g.use_medicine()
				var before:float=g.health
				# Dodging bot: step sideways from any telegraphed attack, else drift home.
				var dir:=Vector2.ZERO
				for a in g.wildlife.animals:
					if str(a.state) in ["windup","charge_warn","charge"] and a.p.distance_to(g.player)<220.0:
						var away:Vector2=(g.player-a.p).normalized()
						dir=Vector2(-away.y,away.x)
						if (g.player+dir*40.0).distance_to(b.BEACON_POS)>190.0:dir=-dir
						break
				if dir==Vector2.ZERO and g.player.distance_to(guard)>12.0:dir=(guard-g.player).normalized()*0.6
				g.move_player(dir,1.0/30.0)
				g.update_wildlife(1.0/30.0);b.update(g,1.0/30.0);g.beacon_glow=b.glow()
				dmg+=maxf(0.0,before-g.health);t+=1.0/30.0
			rows.append({"lit":b.stage=="lit","died_at":snappedf(t,0.1) if g.health<=0 else -1.0,"damage":snappedf(dmg,1)})
			g.queue_free()
		out["night%d"%night]=rows
	print("WATCH ",JSON.stringify(out))
	quit()
