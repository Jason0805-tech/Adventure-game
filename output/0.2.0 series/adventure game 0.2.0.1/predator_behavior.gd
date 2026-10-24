extends RefCounted
const Balance = preload("res://survival_balance.gd")
const Data = preload("res://wildlife_data.gd")

static func update(sim: Variant, game: Variant, a: Dictionary, dt: float) -> void:
	var spec: Dictionary = Data.info(a.species)
	var profile: Dictionary = Balance.night_profile(game.night)
	var light: float = game.survival.light_at(game,game.player)
	var distance: float = a.p.distance_to(game.player)
	var event_notice: float = float(game.night_mod("notice_mult", 1.0)) if game.has_method("night_mod") else 1.0
	var notice: float = float(spec.notice)*float(a.temperament.notice)*float(profile.notice)*(1.0-0.30*light)*event_notice
	var sight: bool = distance < notice and sim._line_clear(game,a.p,game.player)
	a.charge_cooldown = maxf(0,float(a.get("charge_cooldown",5.0))-dt)
	a.pursuit = float(a.get("pursuit",0.0))
	a.courage = maxf(0,float(a.get("courage",0.0))+(dt if sight else -dt*2.0))
	var grace: float = float(profile.grace)
	if a.get("shadow",false): grace = 4.0
	if a.age < grace:
		a.moving = false
		return
	if a.state == "windup":
		if a.timer <= 0:
			_hit(sim,game,a,float(spec.attack_range)+3.0,float(spec.damage))
			sim._set_state(a,"recover",float(spec.recovery)+light*0.9)
		return
	if a.state == "charge_warn":
		if a.timer <= 0:
			sim._set_state(a,"charge",0.62)
			a.charge_hit = false
			a.goal = a.p+(a.locked_aim-a.p).normalized()*125.0
			a.path = PackedVector2Array([a.goal]); a.cursor = 0; a.repath = 2.0
		return
	if a.state == "charge":
		var before: Vector2 = a.p
		sim._move_toward(game,a,a.goal,float(profile.charge_speed),dt)
		if not a.get("charge_hit",false) and _hit(sim,game,a,55.0,18.0): a.charge_hit = true
		if a.timer <= 0 or a.p.distance_to(before) < 0.05:
			a.charge_cooldown = float(profile.charge_cooldown) * (float(game.night_mod("charge_mult", 1.0)) if game.has_method("night_mod") else 1.0)
			sim._set_state(a,"recover",2.1+light)
		return
	if a.state == "recover" or a.state == "exhausted":
		if a.timer > 0:
			# Hit and back off: a recovering hunter gives ground instead of
			# pinning the player against scenery with its body.
			if distance < 115.0:
				var away: Vector2 = (a.p - game.player).normalized()
				if away.length_squared() < 0.01: away = Vector2.RIGHT.rotated(sim.rng.randf() * TAU)
				var retreat: Vector2 = game.player + away * 130.0
				if not sim._walkable(game, a, retreat): retreat = game.player + away.rotated(0.8) * 130.0
				sim._move_toward(game, a, retreat, float(spec.speed) * 1.4, dt)
			return
		a.pursuit = 0.0
		sim._rest(a)
	# Faster wolves have finite pursuit stamina. A light slows pursuit; the
	# long recovery and locked bite aim let a normal 108-unit player disengage.
	if a.state == "chase": a.pursuit += dt
	else: a.pursuit = maxf(0,float(a.pursuit)-dt*0.5)
	if float(a.pursuit) >= float(profile.pursuit):
		a.awareness = 0.0; a.courage = 0.0
		sim._set_state(a,"exhausted",4.5)
		return
	# Hunters following a scent or a noise may range much further from home.
	var leash: float = 1250.0 if a.get("hunting", false) else maxf(650,float(a.temperament.roam)+200)
	var leashed: bool = a.p.distance_to(a.home)>leash
	# The beacon fire holds hunters back far longer while it is guarded.
	var courage_needed: float = float(profile.courage_delay)
	if game.get("beacon") != null and game.beacon.igniting() and a.p.distance_to(game.beacon.BEACON_POS) < 280.0: courage_needed *= 2.5
	var deterred: bool = light >= 0.45 and float(a.courage) < courage_needed
	if sight and not deterred and not leashed:
		a.last_seen = game.player
		a.awareness = minf(3.5,float(a.temperament.memory))
		var my_turn: bool = _attack_turn(sim, game, a)
		if distance <= float(spec.attack_range) and not my_turn:
			# Taking turns: wait at the edge of the fight instead of piling in.
			sim._set_state(a,"investigate",0.8); a.activity = "circle"
			a.goal = game.player + (a.p - game.player).normalized().rotated(0.9) * 120.0
			a.repath = 0.0
			return
		if distance <= float(spec.attack_range):
			sim._set_state(a,"windup",float(spec.windup)+light*0.25)
			a.warning_duration = float(a.timer)
			a.locked_aim = game.player; a.attack_direction = (game.player-a.p).normalized(); a.activity = "attack"
			sim._try_facing(game,a,(game.player-a.p).normalized())
			return
		if a.species == "bear" and not a.get("shadow",false) and a.charge_cooldown <= 0 and distance > 95 and distance < 200 and light < 0.55 and my_turn:
			sim._set_state(a,"charge_warn",1.05)
			a.warning_duration = 1.05; a.locked_aim = game.player; a.attack_direction = (game.player-a.p).normalized(); a.activity = "attack"
			sim._try_facing(game,a,(game.player-a.p).normalized())
			return
		sim._set_state(a,"chase"); a.activity = "hunt"
		if a.decision <= 0 or a.p.distance_to(a.goal) < 18:
			a.goal = _flank_goal(sim, game, a); a.decision = sim.rng.randf_range(0.24,0.48); a.repath = 0.0
	elif leashed:
		a.awareness = 0.0; sim._set_state(a,"return"); a.goal = a.home
	elif a.state in ["chase","investigate"]:
		# No continuous omniscient scent lock through obstacles. Investigate the
		# last observed position for a bounded memory, then give up.
		if a.awareness > 0:
			sim._set_state(a,"investigate",3.5); a.goal = a.last_seen; a.activity = "listen"
			if a.p.distance_to(a.goal) < 18: sim._idle_look(game,a); return
		else: sim._rest(a)
	if a.state == "idle":
		sim._idle_look(game,a)
		if a.timer > 0: return
		sim._set_state(a,"wander"); a.activity = "roam"; a.goal = sim._new_wander_goal(game,a)
	if a.state == "return" and a.p.distance_to(a.home) < 30: sim._rest(a); return
	if a.state == "wander" and a.p.distance_to(a.goal) < 12:
		# A trail that went cold: rest briefly, then pick up the scent again.
		if a.get("hunting", false): a.home = a.p
		sim._rest(a); return
	var speed: float = float(spec.speed)*float(a.temperament.pace)
	var chase_speed: float = float(profile.wolf_speed if a.species == "wolf" else profile.bear_speed)
	if a.get("shadow",false): chase_speed = 103.0
	if a.state == "chase": speed = chase_speed*(1.0-light*0.28)
	elif a.state == "investigate": speed = chase_speed*0.70
	sim._move_toward(game,a,a.goal,speed,dt)

static func _attack_turn(sim: Variant, game: Variant, a: Dictionary) -> bool:
	# At most one hunter attacks at a time (two from night 3); fairer fights.
	var limit: int = 1 if int(game.night) <= 2 else 2
	var busy := 0
	for other in sim.animals:
		if other == a: continue
		if str(other.state) in ["windup", "charge_warn", "charge"]: busy += 1
	return busy < limit

static func _flank_goal(sim: Variant, game: Variant, a: Dictionary) -> Vector2:
	# Pack tactics: when another wolf is already on the player, this one swings
	# wide to a side instead of queueing behind it. Close in once near.
	if a.species != "wolf" or a.p.distance_to(game.player) < 90.0: return game.player
	for other in sim.animals:
		if other == a or other.species != "wolf" or str(other.state) != "chase": continue
		if other.p.distance_to(game.player) > 260.0: continue
		var line: Vector2 = (game.player - other.p).normalized()
		var side: Vector2 = Vector2(-line.y, line.x) * (1.0 if int(a.uid) % 2 == 0 else -1.0)
		var flank: Vector2 = game.player + side * 95.0
		if sim._walkable(game, a, flank): return flank
	return game.player

static func _hit(sim: Variant, game: Variant, a: Dictionary, reach: float, damage: float) -> bool:
	var relative: Vector2 = game.player-a.p
	var aim: Vector2 = a.locked_aim-a.p
	if relative.length() > reach or a.get("attack_direction",aim.normalized()).dot(relative.normalized()) < 0.55: return false
	if sim.player_hit_grace > 0 or not sim._line_clear(game,a.p,game.player): return false
	var species: String = "shadow" if a.get("shadow",false) else str(a.species)
	var dealt: float = game.wildlife_damage(damage,species)
	sim.player_hit_grace = Data.PLAYER_HIT_GRACE
	sim.last_events.append({"type":"player_hit","species":species,"damage":dealt})
	return true
