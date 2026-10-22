"""Applies the v0.1.7 beacon quest integration to main.gd (run once in the release folder)."""
from pathlib import Path
p=Path('main.gd');s=p.read_text()
def rep(a,b,count=1):
    global s
    n=s.count(a)
    assert n==count,(n,a[:80])
    s=s.replace(a,b)
rep('# v0.1.6-alpha.4: separate solid ground footprints, overhead paint and contact depth.','# v0.1.7: beacon main quest; separate solid ground footprints, overhead paint and contact depth.')
rep('var survival = preload("res://sanity_system.gd").new()\n','var survival = preload("res://sanity_system.gd").new()\nvar beacon = preload("res://beacon_quest.gd").new()\nvar beacon_glow := Vector3.ZERO # x, y, strength of the beacon fire for lighting\n')
rep('var message := "Survive three nights. Explore by day; wolves and bears roam after dusk."','var message := "Repair the old beacon to escape the forest. Talk to Rowan at camp."')
rep('	collision_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://collision_profiles.json"))\n','	collision_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://collision_profiles.json"))\n	beacon.load_art(self)\n')
rep('	for texture in art + variant_art + harvest_art + prop_art + utility_props:\n','	for texture in art + variant_art + harvest_art + prop_art + utility_props + beacon.model_textures():\n')
rep('	print("GAME_READY v0.1.6-alpha.5")','	print("GAME_READY v0.1.7")')
rep('''		if p.distance_to(gate) < 210 or p.distance_to(npc_scout) < 170:
			continue
''','''		if p.distance_to(gate) < 210 or p.distance_to(npc_scout) < 170:
			continue
		if quest_site_near(p, 125.0) or quest_site_near(p + Vector2(65, 24), 95.0):
			continue
''')
rep('''	rebuild_obstacles()
	# Keep the main east/west and north/south paths clear.
''','''	rebuild_obstacles()
	beacon.setup(self)
	# Keep the main east/west and north/south paths clear.
''')
rep('''func tree_distance(p: Vector2) -> float:''','''func quest_site_near(p: Vector2, radius: float) -> bool:
	for kind in beacon.kinds():
		if p.distance_to(beacon.position(kind)) < radius: return true
	return false

func tree_distance(p: Vector2) -> float:''')
rep('''			var close:bool=false
			for vein in ore_veins:''','''			var close:bool=quest_site_near(p,120.0)
			for vein in ore_veins:''')
rep('''		"bench": return {"texture": utility_props[0], "foot": p + Vector2(0, 8), "height": 82.0, "profile": "bench", "mirror": false}
''','''		"bench": return {"texture": utility_props[0], "foot": p + Vector2(0, 8), "height": 82.0, "profile": "bench", "mirror": false}
		"beacon", "rune_rock", "shrine": return beacon.model_spec(kind)
''')
rep('''	entries.append(scenery_entry("cabin", Vector2(350,635)));entries.append(scenery_entry("gate", gate+Vector2(0,30)))
''','''	entries.append(scenery_entry("cabin", Vector2(350,635)));entries.append(scenery_entry("gate", gate+Vector2(0,30)))
	for kind in beacon.kinds():entries.append(scenery_entry(kind, beacon.position(kind)))
''')
rep('''	append_model_body("gate", gate + Vector2(0, 30))
''','''	append_model_body("gate", gate + Vector2(0, 30))
	for kind in beacon.kinds(): append_model_body(kind, beacon.position(kind))
''')
rep('''		for bench in workbenches:candidates.append({"pos":bench.p,"kind":"bench","uid":bench.uid})
''','''		for bench in workbenches:candidates.append({"pos":bench.p,"kind":"bench","uid":bench.uid})
		for quest in beacon.targets():
			if quest.kind!="rune_rock":candidates.append(quest)
''')
rep('''		if not ore_veins[i].depleted:candidates.append({"pos":ore_veins[i].p,"kind":"ore","index":i})
	var item:Dictionary=selected_item()''','''		if not ore_veins[i].depleted:candidates.append({"pos":ore_veins[i].p,"kind":"ore","index":i})
	if beacon.rune_valid():candidates.append({"pos":beacon.RUNE_POS,"kind":"rune_rock"})
	var item:Dictionary=selected_item()''')
rep('''		"gate":notify("Survive all three nights to leave the forest.")
''','''		"gate":notify("The gate is sealed. Light the old beacon by the northern trail to open the way." if beacon.stage!="lit" else "The way is open.")
		"beacon":beacon.interact_beacon(self)
		"shrine":beacon.take_core(self)
''')
rep('''		"tree","ore","water":
			if not begin_action(target):interaction_cooldown=0.35''','''		"tree","ore","water","rune_rock":
			if not begin_action(target):interaction_cooldown=0.35''')
rep('''		"ore":return int(target.index)<ore_veins.size() and not ore_veins[int(target.index)].depleted
		"water"''','''		"ore":return int(target.index)<ore_veins.size() and not ore_veins[int(target.index)].depleted
		"rune_rock":return beacon.rune_valid()
		"water"''')
rep('''	var required:String={"tree":"axe","ore":"pick","water":"rod"}.get(target.get("kind",""),"")''','''	var required:String={"tree":"axe","ore":"pick","rune_rock":"pick","water":"rod"}.get(target.get("kind",""),"")''')
rep('''"pick":"Equip a pickaxe to mine iron ore."''','''"pick":"Equip a pickaxe to mine iron ore or break the rune rock."''')
rep('''		"water":
			var before:int=bag.count("fish")''','''		"rune_rock":beacon.mine_hit(self,int(spec.get("strength",1)))
		"water":
			if beacon.fish_catch(self,target.pos):
				if not bag.usable(uid):notify(Data.label(action.id)+" broke. Repair it at a workbench.")
				return
			var before:int=bag.count("fish")''')
rep('''(tool == "pick" and target.kind != "ore")''','''(tool == "pick" and target.kind not in ["ore", "rune_rock"])''')
rep('''		"ore":return "Hold E  Mine ore - pickaxe required"
''','''		"ore":return "Hold E  Mine ore - pickaxe required"
		"beacon","rune_rock","shrine":return beacon.prompt(str(target.kind))
''')
rep('''	if Data.info(item.id).category=="material":
		notify("Materials stay in the backpack. Equip a tool, food or workbench.");return false''','''	if Data.info(item.id).category in ["material","quest"]:
		notify("Materials and beacon parts stay in the backpack. Equip a tool, food or workbench.");return false''')
rep('''		"resource":return resource_art[index] if index<resource_art.size() else null
	return null''','''		"resource":return resource_art[index] if index<resource_art.size() else null
		"beacon":return beacon.icons[index] if index<beacon.icons.size() else null
	return null''')
rep('''	result_text="Dawn has arrived. You survived another night in the forest."
	if survived>=3:
		won=true;phase="won"
	else:phase="result"''','''	result_text="Dawn has arrived. You survived another night in the forest."
	beacon.on_dawn(self)
	phase="result"''')
rep('''func next_day()->void:''','''func beacon_escape()->void:
	if won or lost:return
	won=true;phase="won"
	inventory=false;crafting=false;dialog="";moving=false;cancel_action()
	result_text="The beacon blazes above the trees and the northern gate swings open."
	print("BEACON_ESCAPE night=",night)

func next_day()->void:''')
p.write_text(s);print("ok")
