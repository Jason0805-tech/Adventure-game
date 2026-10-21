extends SceneTree
const Test = preload("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.1/test_lighting.gd")
func _initialize():
 var world = Test.World.new();root.add_child(world)
 world.phase="night"; world.night_elapsed=40; world.torch_lit=true
 var light=load("res://world_lighting.gd").new()
 var start=Time.get_ticks_usec()
 for i in range(100):
  world.player+=Vector2(0.5,0.2)
  light.darkness_mesh(world,Vector2(1100,720))
 print("LIGHTING_MESH_MEAN_MS ",(Time.get_ticks_usec()-start)/100000.0)
 world.queue_free();quit()
