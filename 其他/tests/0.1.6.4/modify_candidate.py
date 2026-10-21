from pathlib import Path
root=Path(__file__).resolve().parent/'candidate'
def edit(name, old, new):
 p=root/name;s=p.read_text();assert old in s,(name,old[:100]);p.write_text(s.replace(old,new))
edit('project.godot','Forest Wanderer 0.1.6.3','Forest Wanderer v0.1.6-alpha.4')
edit('wildlife.gd','const Geometry = preload("res://world_geometry.gd")','const Geometry = preload("res://world_geometry.gd")\nconst Balance = preload("res://survival_balance.gd")\nconst Predator = preload("res://predator_behavior.gd")')
edit('wildlife.gd','str(animal.state) == "windup"','str(animal.state) in ["windup","charge_warn"]')
edit('wildlife.gd','"uid":int(animal.uid),"species":str(animal.species),','"uid":int(animal.uid),"species":str(animal.species),"shadow":bool(animal.get("shadow",false)),')
edit('wildlife.gd','float(spec.get("windup",1.0)) if warning','float(animal.get("warning_duration",spec.get("windup",1.0))) if warning')
# Light is an AI deterrent; never a circular navigation or physical wall.
edit('wildlife.gd','\tif p.distance_to(Data.CAMP) < Data.CAMP_SAFE_RADIUS:return false\n','')
edit('wildlife.gd','p.distance_to(Data.CAMP)<Data.CAMP_SAFE_RADIUS or ','')
edit('wildlife.gd','if str(animal.species) == species:count += 1','if str(animal.species) == species and not animal.get("shadow",false):count += 1')
edit('wildlife.gd','\t\twhile count < int(Data.info(species).cap):','\t\tvar cap: int = int(Balance.night_profile(game.night).wolves) if species == "wolf" else int(Data.info(species).cap)\n\t\twhile count < cap:')
edit('wildlife.gd','rng.randf_range(Data.RESPAWN_DELAY*0.78,Data.RESPAWN_DELAY*1.24)','rng.randf_range(respawn_delay(game)*0.90,respawn_delay(game)*1.10)')
p=root/'wildlife.gd';s=p.read_text();a=s.index('\tvar safe:bool=');b=s.index('\telse:\n\t\tif clear_sight:',a)
s=s[:a]+'''\tif spec.predator:
\t\tPredator.update(self,game,animal,dt)
\t\treturn
\tvar notice:float=float(spec.notice)*float(animal.temperament.notice)
\tvar clear_sight:bool=distance<notice and _line_clear(game,animal.p,game.player)
\tif clear_sight:
\t\tanimal.last_seen=game.player
\t\tanimal.awareness=float(animal.temperament.memory)
'''+s[b:].replace('\telse:\n\t\tif clear_sight:', '\tif not spec.predator:\n\t\tif clear_sight:',1)
s+='''
func respawn_delay(game: Variant) -> float:
\treturn float(Balance.night_profile(game.night).respawn) if period == "night" else Data.RESPAWN_DELAY

func has_shadow() -> bool:
\tfor animal in animals:
\t\tif animal.get("shadow",false): return true
\treturn false

func dismiss_shadow() -> void:
\tanimals = animals.filter(func(a): return not a.get("shadow",false))

func spawn_shadow(game: Variant) -> bool:
\tif has_shadow() or game.phase != "night" or game.sanity >= 30 or game.survival.light_at(game,game.player) >= 0.45: return false
\t# First use the existing connected habitat sampler; never put a collider on
\t# the player, in a wall, or in a disconnected pocket. Bounded attempts only.
\tfor attempt in range(12):
\t\tif not _spawn_one(game,"wolf"): return false
\t\tvar a: Dictionary = animals.back()
\t\tvar distance: float = a.p.distance_to(game.player)
\t\tif distance >= 360 and distance <= 640 and game.survival.light_at(game,a.p) < 0.2:
\t\t\ta.shadow = true; a.hp = 42.0; a.age = 0.0
\t\t\treturn true
\t\tanimals.pop_back()
\treturn false
'''
s=s.replace('kills[animal.species] = int(kills.get(animal.species,0))+1','if not animal.get("shadow",false): kills[animal.species] = int(kills.get(animal.species,0))+1')
p.write_text(s)
# Update native info to match tuned speed (night profile is authority).
edit('wildlife_data.gd','"chase_speed":95.0','"chase_speed":116.0')
edit('wildlife_data.gd','"chase_speed":68.0','"chase_speed":74.0')
