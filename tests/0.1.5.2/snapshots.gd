extends SceneTree
func _initialize(): call_deferred("capture")
func capture():
 var game=load("res://../../tests/0.1.5.2/snapshot_game.gd").new()
 game.resource_seed=152
 root.add_child(game)
 game.set_process(false)
 game.message_time=0
 game.day_time=22
 game.camera=Vector2(0,250)
 game.reset_capture();game._draw();game.save_capture("day")
 game.weapons.append("Large stone sword");game.sword=true
 for d in range(12):
  game.player=Vector2(540,720)
  game.facing=Vector2(sin(d*TAU/12),cos(d*TAU/12))
  game.reset_capture();game._draw();game.save_capture("turn-%02d"%d)
 for sample in range(8):
  game.moving=true
  game.walk_distance=game.WALK_STRIDE*sample/8.0
  game.facing=Vector2.RIGHT
  game.reset_capture();game._draw();game.save_capture("walk-%02d"%sample)
 game.moving=false
 for label in ["behind-logs","in-front-of-logs"]:
  game.player=Vector2(512,624 if label=="behind-logs" else 674)
  game.reset_capture();game._draw();game.save_capture(label)
 game.items[0].taken=true
 game.health=37;game.fullness=12;game.medicine=1
 game.player=Vector2(660,980);game.camera=Vector2(210,470)
 game.reset_capture();game._draw();game.save_capture("forest-and-low-vitals")
 game.inventory=true
 game.reset_capture();game._draw();game.save_capture("backpack")
 game.inventory=false;game.crafting=true
 game.reset_capture();game._draw();game.save_capture("crafting")
 game.crafting=false;game.phase="choice"
 game.reset_capture();game._draw();game.save_capture("night")
 # Enlarged model consistency sheet, using the exact game paint function.
 game.reset_capture();game.camera=Vector2.ZERO;game.phase="day";game.moving=false
 game.record_draw_rect(Rect2(0,0,1100,720),Color("8aab78"))
 game.label_at(Vector2(28,32),"30-DEGREE HEADINGS + EXACT DIAGONALS / ONE RIGHT HAND",24)
 for d in range(game.FACING_ANGLES.size()):
  var angle=float(game.FACING_ANGLES[d])
  game.facing=Vector2(sin(deg_to_rad(angle)),cos(deg_to_rad(angle)))
  var p=Vector2(125+(d%4)*275,175+(d/4)*165)
  game.draw_ellipse_shadow(p)
  game.draw_traveler(p,1.65)
  game.label_at(p+Vector2(-18,30),"%d deg"%int(angle),16)
 game.save_capture("direction-gallery")
 game.queue_free()
 print("SCENE_CAPTURES_COMPLETE")
 quit()
