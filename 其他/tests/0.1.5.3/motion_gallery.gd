extends SceneTree
func _initialize():call_deferred("capture")
func capture():
 var game=load("res://../../tests/0.1.5.3/snapshot_game.gd").new()
 game.resource_seed=153;root.add_child(game);game.set_process(false)
 game.weapons.append("Large stone sword");game.moving=true;game.camera=Vector2.ZERO;game.day_time=30
 for frame in range(8):
  game.walk_distance=game.WALK_STRIDE*frame/8.0
  game.reset_capture()
  game.record_draw_rect(Rect2(0,0,1000,360),Color("8aab78"))
  game.label_at(Vector2(20,32),"Walking / the weapon follows the same right hand",20)
  for i in range(6):
   var angle=float([0,45,90,180,270,315][i])
   game.facing=Vector2(sin(deg_to_rad(angle)),cos(deg_to_rad(angle)))
   var p=Vector2(85+i*165,260)
   game.draw_ellipse_shadow(p);game.draw_traveler(p,1.65)
   game.label_at(p+Vector2(-30,34),["Front","45 deg","Right","Back","Left","315 deg"][i],17)
  game.save_capture("motion-%02d"%frame,1000,360)
 game.queue_free();print("MOTION_GALLERY_CAPTURE_COMPLETE");quit()
