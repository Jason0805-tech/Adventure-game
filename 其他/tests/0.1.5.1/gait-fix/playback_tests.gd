extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, title: String):
 checks += 1
 if not ok: failures += 1; push_error(title)
func _initialize():
 call_deferred("run")
func run():
 var game = load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.obstacles.clear();game.trees.clear();game.shrubs.clear();game.pond_colliders.clear()
 game.npc_home=Vector2(20,20);game.npc_position=Vector2(40,20)
 for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
  game.player=Vector2(1000,750)
  game.walk_distance=0
  var visited={}
  for frame in range(120):
   var old: Vector2 = game.player
   game.move_player(direction,1.0/60.0)
   game.update_walk(game.player.distance_to(old))
   visited[int(game.walk_distance/game.WALK_STRIDE*4)%4]=true
  check(visited.size()==4,"Every painted key pose is reached in all directions")
  check(abs(game.player.distance_to(Vector2(1000,750))-game.SPEED*2)<0.1,"Movement independent of direction")
  game.update_walk(0)
  var old_phase: float=game.walk_distance
  for i in range(60):game.update_walk(0)
  check(not game.moving and game.walk_distance==old_phase,"Stopping freezes walk phase")
 game.player=Vector2(1000,750)
 game.obstacles.clear();game.obstacles.append(Rect2(1012,720,60,80))
 for i in range(60):
  var old:Vector2=game.player
  game.move_player(Vector2.RIGHT,1.0/60)
  game.update_walk(game.player.distance_to(old))
 check(not game.moving,"Wall contact does not animate empty steps")
 var phase:float=game.walk_distance
 game.paused=true
 game._process(0.1)
 check(not game.moving and game.walk_distance==phase,"Pause freezes animation")
 check(game.step_art.size()==3,"Replacement painted poses loaded")
 for tex in game.step_art:
  check(tex.get_width()>100 and tex.get_image().detect_alpha()!=Image.ALPHA_NONE,"Replacement has valid painted pixels and alpha")
 print("GAIT_RESULT: ",checks," checks, ",failures," failures")
 game.queue_free()
 quit(1 if failures else 0)
