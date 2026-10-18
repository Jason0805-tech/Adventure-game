extends SceneTree
const Game=preload("res://main.gd")
var checks:=0
var failures:=0
func check(ok:bool,title:String):
 checks+=1
 if not ok:failures+=1;push_error("FAIL "+title)
func fresh(seed_value:int=152):
 var g=Game.new();g.resource_seed=seed_value;g.build_world();return g
func action(g,index:int):
 g.start_night();g.advance_phase(2.1);g.choose_action(index);g.advance_phase(2.6)
func _initialize():
 call_deferred("run")
func run():
 for i in range(5):
  var g=fresh();var r=g.RECIPES[i]
  g.branches=r[1];g.rocks=r[2];g.ropes=r[3];g.craft_recipe(i)
  check(g.power==r[4] and g.weapons==[r[0]] and g.branches+g.rocks+g.ropes==0,"Recipe ingredients and power")
  g.free()
 var g=fresh();g.rocks=1;g.craft_recipe(5)
 check(g.rocks==1 and g.weapons.is_empty(),"Upgrade needs base sword")
 g.weapons.append("Large stone sword");g.power=4;g.craft_recipe(5)
 check(g.power==5 and g.rocks==0 and g.weapons==["Amazing stone sword"],"Sword upgrade replaces base")
 g.free()
 for i in range(3):
  g=fresh();g.power=10;g.health=70
  g.start_night();g.advance_phase(2.1);g.choose_action(i)
  check(g.fullness==[50,65,100][i] and g.power==[12,11,11][i],"Night costs and rewards")
  check(g.health==(80 if i==1 else 70),"Rest restores health once")
  g.choose_action(i);check(g.power==[12,11,11][i],"Repeated night action ignored")
  g.advance_phase(2.6);g.resolve_night();check(g.survived==1,"One survival credit")
  g.free()
 g=fresh();action(g,1)
 check(g.health==55 and g.survived==1 and not g.lost,"Low power causes a real injury")
 g.next_day();action(g,1)
 check(g.lost and g.health==0 and g.phase=="lost","Fatal subsequent injury ends run")
 g.free()
 g=fresh();g.magic_stones=1;g.medicine=1;action(g,1)
 check(g.health==100 and g.magic_stones==0 and g.medicine==1,"Magic stone protects before medicine")
 g.next_day();action(g,1)
 check(g.medicine==0 and g.health==75 and g.survived==2,"Medicine treats night injuries once")
 g.free()
 g=fresh()
 for day in range(3):
  g.branches=3;g.rocks=4;g.ropes=3;g.craft_recipe(0);action(g,1)
  if day<2:g.next_day()
 check(g.won and g.survived==3 and g.night==3,"Three-night gear victory")
 g.next_day();check(g.phase=="won" and g.night==3,"No fourth night")
 g.free()
 g=fresh()
 for choice in [0,2,0]:
  action(g,choice);g.next_day()
 check(g.won and g.magic_stones==0 and g.medicine==0,"Three-night rescue route")
 g.free()
 g=fresh();var original_count:int=g.items.size()
 g.branches=3;g.rocks=4;g.ropes=3
 for _i in range(20):g.collect_item(0)
 check(g.branches+g.rocks+g.ropes==10 and not g.items[0].taken,"Full backpack rejects pickup without corrupting node")
 g.drop_material(0);check(g.branches==2 and g.items[-1].dropped,"Drop is preserved as loose material")
 g.collect_item(g.items.size()-1);check(g.branches==3,"Dropped resource can be collected")
 g.craft_recipe(0);g.collect_item(0);var kept:int=g.branches
 action(g,1);g.next_day()
 check(g.branches==kept and g.items.size()==original_count and not g.items[0].taken,"Dawn renews environment nodes and removes dropped duplicates")
 g.free()
 g=fresh();g.health=55;g.medicine=2;g.use_medicine()
 check(g.health==95 and g.medicine==1,"H heals and consumes one medicine")
 g.use_medicine();check(g.health==100 and g.medicine==0,"Healing caps at full health")
 g.medicine=1;g.use_medicine();check(g.medicine==1,"Full-health medicine is not wasted")
 g.fullness=0;g.advance_vitals(4);check(g.health==94,"Starving drains health with elapsed time")
 g.paused=true;g.advance_vitals(100);check(g.health==94,"Pause freezes vitals")
 g.paused=false;g.fullness=1;g.hunger_elapsed=0;g.health=100;g.advance_vitals(17)
 check(abs(g.health-99.5)<0.01,"Only time after fullness reaches zero damages health")
 var berry:=-1
 for i in range(g.items.size()):
  if g.items[i].kind=="berry":berry=i;break
 g.fullness=10;g.branches=10;g.collect_item(berry)
 check(g.fullness==32 and g.items[berry].taken and g.branches==10,"Eating berries works with a full material bag")
 g.free()
 g=fresh();g.advance_day(89.5);check(g.phase=="day" and g.clock_text()=="00:01","Day countdown deadline")
 g.inventory=true;g.crafting=true;g.dialog="test";g.advance_day(.5)
 check(g.phase=="dusk" and not g.inventory and not g.crafting and g.dialog.is_empty(),"Automatic night closes panels")
 g.free()
 # Ecology, randomness, accessible approach and non-overlapping spawns.
 var first_signature=""
 for seed_value in range(8):
  g=fresh(150+seed_value)
  var counts={"branch":0,"rock":0,"rope":0,"berry":0};var road_count:=0
  for item in g.items:
   counts[item.kind]+=1
   if g.near_path(item.pos):road_count+=1
   if item.kind in ["branch","berry"]:check(g.tree_distance(item.pos)<=116.1,"Woody shrubs occur by trees")
   if item.kind=="rope":check(g.tree_distance(item.pos)>=92 and g.forest_density(item.pos)<3,"Fiber grass avoids dense shade")
   check(g.walkable(item.pos+Vector2(0,30)),"Every node has a reachable nearby approach")
  check(counts=={"branch":22,"rock":18,"rope":18,"berry":9},"Resource targets are met")
  check(road_count<g.items.size()/4,"Most resources are off the paths")
  var signature=str(g.items[0].pos)+str(g.items[10].pos)
  if seed_value==0:first_signature=signature
  else:check(signature!=first_signature,"Different seeds change placement")
  g.free()
 # 30-degree facing, weapon identity, depth order and wall stopping.
 g=fresh()
 for d in range(12):
  check(g.avatar_direction(Vector2(sin(d*TAU/12),cos(d*TAU/12)))==g.FACING_ANGLES.find(d*30),"Every 30-degree heading maps to its own image")
 for angle in [45,135,225,315]:
  check(g.avatar_direction(Vector2(sin(deg_to_rad(angle)),cos(deg_to_rad(angle))))==g.FACING_ANGLES.find(angle),"Exact diagonal heading")
 for i in range(6):
  g.weapons.clear();g.weapons.append(g.RECIPES[i][0])
  check(g.equipped_weapon_index()==i,"Every recipe selects the matching held model")
 for player_y in [624,674]:
  g.player=Vector2(512,player_y);var order=g.scenery_entries();var actor:=-1;var wood:=-1
  for i in range(order.size()):
   if order[i].kind=="player":actor=i
   if order[i].kind=="prop" and order[i].index==0:wood=i
  check((actor<wood)==(player_y<649),"Wood pile occludes the traveler on the correct side")
 g.items.clear();g.obstacles.clear();g.pond_colliders.clear();g.npc_home=Vector2.ZERO;g.npc_position=Vector2.ZERO
 g.player=Vector2(500,500);g.obstacles.append(Rect2(530,470,20,60))
 for i in range(120):
  var previous:Vector2=g.player;g.move_player(Vector2.RIGHT,1.0/60);g.update_walk(g.player.distance_to(previous))
 check(not g.moving and g.avatar_frame()==8,"Wall contact uses idle instead of empty stepping")
 g.obstacles.clear();g.player=Vector2(1000,750);g.facing=Vector2.DOWN
 var turns={}
 for i in range(16):
  g.move_player(Vector2.RIGHT,1.0/60);turns[g.FACING_ANGLES[g.avatar_direction(g.facing)]]=true
 check(turns.has(30) and turns.has(60) and turns.has(90),"Real key turns pass through intermediate views")
 g.facing=Vector2(sin(deg_to_rad(330)),cos(deg_to_rad(330)))
 g.move_player(Vector2.DOWN,1.0/60)
 check(g.facing.y>0.85,"Facing takes the short turn across zero degrees")
 g.free()
 print("FEEDBACK_RESULT: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
