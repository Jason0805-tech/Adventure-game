"""v0.1.7 HUD, dialog, lighting and wildlife hooks for the beacon quest."""
from pathlib import Path
import re
def patch(path,pairs):
    p=Path(path);s=p.read_text()
    for a,b in pairs:
        n=s.count(a);assert n==1,(path,n,a[:90]);s=s.replace(a,b)
    p.write_text(s)
rowan_old=re.search(r'dialog="Rowan - Camp guide\\n[^"]*"',Path('main.gd').read_text()).group(0)
rowan_new='dialog="Rowan - Camp guide\\n\\nThe only way out is the old beacon by the northern trail.\\nIt needs three lost parts: a lens, a gear and an ember core.\\nA glint on Stillwater Lake hides the lens. Fish right there.\\nA carved rune rock by the southeast ore hides the gear.\\nThe core rests on a shrine deep in the northwest woods.\\nRepair it with 4 logs + 2 ore, then light it after dark.\\nGuard the fire for 60 seconds. Its light draws predators.\\n\\nGather and craft tools and torches by day. Prepare for night.\\nB opens your backpack. Menus pause time and animals."'
patch('main.gd',[
 (rowan_old,rowan_new),
 ('\\n\\nStay alive through three nights. Menus pause the world."','\\n\\nLight the old beacon to escape. Menus pause the world."'),
 ('			survival.update(self,dt)\n','			survival.update(self,dt)\n			beacon.update(self,dt)\n'),
 ('	var screen:Vector2=get_viewport_rect().size\n	if mobile.enabled and screen!=mobile_screen:','	beacon_glow=beacon.glow()\n	var screen:Vector2=get_viewport_rect().size\n	if mobile.enabled and screen!=mobile_screen:'),
 ('	for entry in paint_entries(true): draw_paint_entry(entry)\n','	beacon.draw_ground(self)\n	for entry in paint_entries(true): draw_paint_entry(entry)\n'),
 ('	draw_action_effects()\n	var target := nearest_target()','	draw_action_effects()\n	beacon.draw_progress(self)\n	var target := nearest_target()'),
 ('"v0.1.6-alpha.5  /  THREE NIGHTS"','"v0.1.7  /  THE OLD BEACON"'),
 ('"Survived %d / 3   |   Day %d" % [survived,night]','"Day %d   |   Beacon parts %d / 3" % [night,beacon.parts_found()]'),
 ('''			paper_panel(Rect2(20,262,385 if in_refuge else 495,33),Color("e6d8b3"),8)
			label_at(Vector2(30,285),hint,15)
''','''			paper_panel(Rect2(20,262,385 if in_refuge else 495,33),Color("e6d8b3"),8)
			label_at(Vector2(30,285),hint,15)
		var goal:String="GOAL  "+beacon.objective(self)
		var goal_y:float=304.0 if phase=="night" else 262.0
		paper_panel(Rect2(20,goal_y,font.get_string_size(goal,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x+24,33),Color("efe0b0"),8)
		label_at(Vector2(32,goal_y+23),goal,15,Color("6a4a22"))
'''),
 ('if won:title="THREE NIGHTS SURVIVED - YOU WIN!"','if won:title="BEACON LIT - YOU ESCAPED THE FOREST!"'),
 ('"Medicine left: %d   |   Nights survived: %d / 3" % [bag.count("medicine"),survived]','"Medicine left: %d   |   Nights survived: %d   |   Beacon parts %d / 3" % [bag.count("medicine"),survived,beacon.parts_found()]'),
 ('if won:label_at(base+Vector2(35,365),"Dawn breaks. You leave the forest safely.",21)','if won:label_at(base+Vector2(35,365),"Its light opens the northern gate. You leave the forest at last.",21)'),
])
patch('mobile_ui.gd',[
 ('"v0.1.6-alpha.5  ·  THREE NIGHTS" if screen.x>=1230 else "v0.1.6-alpha.5"','"v0.1.7  ·  THE OLD BEACON" if screen.x>=1230 else "v0.1.7"'),
 ('"Day %d   ·   Survived %d / 3   ·   Bag %d / 24"%[game.night,game.survived,game.bag.used_slots()]','"Day %d   ·   Beacon %d / 3   ·   Bag %d / 24"%[game.night,game.beacon.parts_found(),game.bag.used_slots()]'),
 ('''		text(game,Vector2(42,y+37),str(sky.title),26)
''','''		text(game,Vector2(42,y+37),str(sky.title),26)
		var goal:String=game.beacon.objective(game)
		game.paper_panel(Rect2(28,y+64,minf(screen.x-56,game.font.get_string_size(goal,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+32),44),PAPER,8)
		text(game,Vector2(44,y+94),goal,22,Color("6a4a22"))
'''),
 ('if game.won:title="THREE NIGHTS SURVIVED!"','if game.won:title="BEACON LIT - YOU ESCAPED!"'),
 ('"Nights survived: %d / 3"%game.survived','"Nights survived: %d   ·   Beacon parts %d / 3"%[game.survived,game.beacon.parts_found()]'),
])
# The beacon fire is an authored light: it lifts darkness and protects sanity.
patch('world_lighting.gd',[
 ('''func _field_exposure(p: Vector2, dark: float, player: Vector2, torch: bool) -> float:''','''func _field_exposure(p: Vector2, dark: float, player: Vector2, torch: bool, beacon := Vector3.ZERO) -> float:'''),
 ('''	return clampf(1.0 - (1.0 - base) * (1.0 - camp) * (1.0 - torch_light), 0.0, 1.0)''','''	var beacon_light := _radial(p.distance_to(Vector2(beacon.x, beacon.y)), BEACON_INNER, BEACON_RADIUS) * 0.97 * beacon.z * artificial if beacon.z > 0.0 else 0.0
	return clampf(1.0 - (1.0 - base) * (1.0 - camp) * (1.0 - torch_light) * (1.0 - beacon_light), 0.0, 1.0)'''),
 ('''const MESH_STEP := 18.0''','''const BEACON_INNER := 70.0
const BEACON_RADIUS := 250.0
const MESH_STEP := 18.0'''),
 ('''	return _field_exposure(p, float(atmosphere(world).darkness), _value(world, "player", Vector2.ZERO), _torch_active(world))''','''	return _field_exposure(p, float(atmosphere(world).darkness), _value(world, "player", Vector2.ZERO), _torch_active(world), _value(world, "beacon_glow", Vector3.ZERO))'''),
 ('''	var torch := _torch_active(world)
	for vertex in _vertices:
		var color := FOG
		color.a = 1.0 - _field_exposure(Vector2(vertex.x, vertex.y) + camera, dark, player, torch)''','''	var torch := _torch_active(world)
	var beacon: Vector3 = _value(world, "beacon_glow", Vector3.ZERO)
	for vertex in _vertices:
		var color := FOG
		color.a = 1.0 - _field_exposure(Vector2(vertex.x, vertex.y) + camera, dark, player, torch, beacon)'''),
])
patch('sanity_system.gd',[
 ('''	return 1.0 - (1.0 - camp) * (1.0 - torch)''','''	var beacon := 0.0
	var glow: Vector3 = game.get("beacon_glow") if game.get("beacon_glow") != null else Vector3.ZERO
	if glow.z > 0.0:
		beacon = (1.0 - smoothstep(70.0,250.0,p.distance_to(Vector2(glow.x,glow.y)))) * 0.97 * glow.z
	return 1.0 - (1.0 - camp) * (1.0 - torch) * (1.0 - beacon)'''),
])
# While the beacon charges, its light is a landmark predators come to inspect.
patch('wildlife.gd',[
 ('''	# The known lantern is a landmark for nearby predators, not knowledge of''','''	if spec.predator and not animal.get("shadow",false) and game.beacon.igniting() and animal.home.distance_to(game.beacon.BEACON_POS)<1100 and rng.randf()<0.7:
		for attempt in range(12):
			var goal:Vector2=game.beacon.BEACON_POS+Vector2.RIGHT.rotated(rng.randf()*TAU)*rng.randf_range(150,240)
			if _walkable(game,animal,goal) and _reachable(game,animal.p,goal):
				animal.last_goal=goal;animal.goals_chosen=int(animal.goals_chosen)+1
				return goal
	# The known lantern is a landmark for nearby predators, not knowledge of'''),
])
print('ok')
