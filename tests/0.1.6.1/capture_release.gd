extends SceneTree
const OUT="res://../../tests/0.1.6.1/"
var game:Variant
var scenes:Array=[]
func _initialize()->void:call_deferred("run")
func save_scene(name:String,description:String)->void:
 game.reset_capture();game._draw();game.save_capture(name,1100,720)
 scenes.append({"name":name,"description":description,"phase":game.phase,"day_time":game.day_time,"night_elapsed":game.night_elapsed,"torch":game.torch_lit,"player":[game.player.x,game.player.y]})
func stage(species:String,p:Vector2,direction:Vector2)->Dictionary:
 var old_size:int=game.wildlife.animals.size()
 assert(game.wildlife._spawn_one(game,species))
 var animal:Dictionary=game.wildlife.animals[old_size]
 animal.p=p;animal.home=p;animal.goal=p+direction*200;animal.facing=direction.normalized()
 animal.age=10;animal.moving=true;animal.walk=game.wildlife.Data.info(species).stride*0.15
 animal.state="wander";animal.timer=1.0
 assert(game.wildlife._ground_clear(game,animal,p),"Staged animal has legal ground: "+species)
 return animal
func run()->void:
 game=load(OUT+"snapshot_game.gd").new();game.resource_seed=161
 root.add_child(game);game.set_process(false)
 for child in game.get_children():child.set_process(false)
 game.message_time=0;game.player=Vector2(1700,850);game.camera=Vector2(1100,430)
 game.elapsed=1.2;game.facing=Vector2.LEFT
 game.bag.add("stone_sword",1);game.auto_equip(game.bag.slots[game.bag.first("stone_sword")].uid)
 game.wildlife.animals.clear()
 stage("rabbit",Vector2(1570,790),Vector2.RIGHT)
 stage("deer",Vector2(1810,740),Vector2.LEFT)
 stage("fox",Vector2(1720,810),Vector2.LEFT)
 for clock in [[0,"dawn"],[81,"noon"],[171,"evening"]]:
  game.phase="day";game.day_time=clock[0]
  save_scene(clock[1],"Staged species composition in the actual clearing; real release lighting and Canvas commands")
 game.phase="dusk";game.phase_time=3
 save_scene("dusk","Dusk at halfway to night; staged composition")
 game.phase="night";game.night_elapsed=45;game.phase_time=45
 game.wildlife.animals.clear()
 stage("wolf",Vector2(1880,790),Vector2.LEFT)
 stage("bear",Vector2(1740,650),Vector2.DOWN)
 save_scene("midnight-unlit","Midnight without a torch: actual predator eye anchors; staged encounter")
 game.bag.add("torch",1);game.toggle_torch()
 save_scene("midnight-torch","Same midnight encounter and camera with a crafted lit torch")
 game.torch_lit=false;game.night_elapsed=88;game.phase_time=88;game.message_time=0
 save_scene("before-dawn","Last seconds of night gradually brighten toward dawn")
 game.phase="night";game.night_elapsed=45;game.phase_time=45
 game.player=Vector2(500,790);game.camera=Vector2(0,310);game.wildlife.animals.clear()
 save_scene("camp-night","Camp lantern is a permanent safe illuminated refuge, without a player torch")
 # Complete gait cycles, actual draw_animal function, at 2x for inspection.
 game.wildlife.animals.clear();game.phase="day";game.day_time=81;game.camera=Vector2.ZERO
 var entries:Array=[]
 for i in range(5):
  var species:String=["rabbit","deer","fox","wolf","bear"][i]
  entries.append({"species":species,"p":Vector2(55+i*105,110),"facing":Vector2.RIGHT,"gait_phase":0.0,"moving":true,"state":"wander","alpha":1.0,"hitflash":0.0,"frame":0})
 for frame in range(32):
  game.reset_capture();game.record_draw_rect(Rect2(0,0,1100,300),Color("b5c69a"))
  game.record_draw_set_transform(Vector2.ZERO,0,Vector2(2,2))
  for animal in entries:
   animal.gait_phase=float(frame)/32
   game.draw_animal_shadow(animal);game.draw_animal(animal)
   game.label_at(animal.p+Vector2(-25,25),animal.species.capitalize(),10)
  game.save_capture("gait-%02d"%frame,1100,300)
 var file:=FileAccess.open(OUT+"preview-manifest.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"scenes":scenes,"method":"Software replay of actual release Canvas commands and native textures; staged compositions are explicitly identified. Not a native GPU manual playthrough."},"\t"))
 game.queue_free();print("RELEASE_PREVIEWS_CAPTURED ",scenes.size());quit()
