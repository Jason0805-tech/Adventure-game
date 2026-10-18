extends SceneTree
func _initialize():
 var game = load("res://main.gd").new()
 game.load_art()
 for i in [0,3]:
  var tex = game.traveler_art[i]
  tex.get_image().save_png("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.1/gait-fix/idle-source-"+str(i)+".png")
  print(i, " ",tex.get_size(), " anchor ",game.foot_anchors[tex])
 game.free()
 quit()
