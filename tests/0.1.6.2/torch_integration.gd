extends SceneTree
var game:Variant
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:push_error(message);quit(1)
func _initialize()->void:call_deferred("run")
func run()->void:
 game=load("res://main.gd").new();game.resource_seed=16101
 root.add_child(game);game.set_process(false)
 game.bag.add("wood_sword",1)
 var weapon_uid:int=game.bag.slots[game.bag.first("wood_sword")].uid
 game.auto_equip(weapon_uid)
 var before_slots:int=game.bag.used_slots()
 game.craft_recipe(10)
 check(game.bag.count("torch")==0 and game.bag.used_slots()==before_slots,"Failed crafting is atomic")
 game.bag.add("branch",2);game.bag.add("rope",2)
 var branches:int=game.bag.count("branch");var fibers:int=game.bag.count("rope")
 game.crafting=true;game.craft_recipe(10)
 check(game.torch_lit and game.torch_fuel==120.0,"Crafted torch lights with full fuel")
 check(game.bag.count("branch")==branches-2 and game.bag.count("rope")==fibers-2,"Torch costs exactly 2 branches + 2 fibers")
 check(game.selected_item().uid==weapon_uid,"Off-hand torch preserves equipped right-hand weapon")
 check(game.bag.validate(),"Fuel inventory validates")
 game.update_torch(10)
 check(game.torch_fuel==120.0,"Crafting pauses fuel")
 game.crafting=false;game.inventory=true;game.update_torch(10)
 check(game.torch_fuel==120.0,"Backpack pauses fuel")
 game.inventory=false;game.paused=true;game.update_torch(10)
 check(game.torch_fuel==120.0,"Escape pauses fuel")
 game.paused=false;game.dialog="Rowan";game.update_torch(10)
 check(game.torch_fuel==120.0,"Conversation pauses fuel")
 game.dialog="";game.update_torch(17.25)
 check(is_equal_approx(game.torch_fuel,102.75),"Fuel tracks actual active elapsed time")
 game.toggle_torch();game.update_torch(15)
 check(not game.torch_lit and is_equal_approx(game.torch_fuel,102.75),"Putting torch out saves fuel")
 game.toggle_torch()
 check(game.torch_lit and is_equal_approx(game.torch_fuel,102.75),"Relighting does not refill torch")
 var uid:int=game.torch_uid
 game.selected_slot=game.bag.index_of_uid(uid)
 game.inventory=true;game.activate_button("drop_selected")
 check(not game.torch_lit and game.torch_uid==-1,"Dropped torch immediately extinguishes")
 var drop_index:int=game.items.size()-1
 check(is_equal_approx(float(game.items[drop_index].fuel),102.75),"World drop retains remaining fuel")
 game.inventory=false;game.collect_item(drop_index)
 var index:int=game.bag.first("torch")
 check(index>=0 and is_equal_approx(float(game.bag.slots[index].fuel),102.75),"Pickup does not reset fuel")
 game.toggle_torch();game.update_torch(102.8)
 check(not game.torch_lit and game.bag.count("torch")==0,"Spent torch is consumed without stale UID")
 check(game.selected_item().uid==weapon_uid,"Burnout keeps weapon equipped")
 game.phase="night";game.night_elapsed=45;game.player=Vector2(1700,1000)
 var unlit:float=game.lighting.sample(game,game.player+Vector2(120,0))
 game.bag.add("torch",1);game.toggle_torch()
 check(game.lighting.sample(game,game.player+Vector2(120,0))>unlit+0.1,"Lit torch actually changes world visibility")
 check(game.lighting.sample(game,game.player+Vector2(161,0))<0.05,"Torch does not reveal beyond 5 metres at midnight")
 check(game.lighting.sample(game,game.CAMP)>0.9,"Camp remains an illuminated refuge")
 # Every rendered facing uses the original left hand; right hand weapon remains untouched.
 for direction in game.FACING_ANGLES:
  game.facing=Vector2(sin(deg_to_rad(direction)),cos(deg_to_rad(direction)))
  for frame in range(9):
   game.action={};game.moving=frame<8;game.walk_distance=frame/8.0*game.WALK_STRIDE
   var grip:Dictionary=game.torch_grip()
   check(grip.offset.is_finite() and grip.offset.length()<60,"Torch grip follows normal human pose")
  for frame in range(6):
   game.action={"elapsed":frame/5.0,"duration":1.0,"target":{"kind":"swing"}}
   var grip:Dictionary=game.torch_grip()
   check(grip.offset.is_finite() and grip.offset.length()<60,"Torch grip follows tool action pose")
 game.action={};game.queue_free()
 print("TORCH_INTEGRATION_PASS ",checks)
 quit(0)
