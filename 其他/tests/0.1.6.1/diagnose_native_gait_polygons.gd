extends SceneTree
func _initialize():call_deferred("run")
func run():
 var world=load("res://main.gd").new();world.resource_seed=160;root.add_child(world);world.set_process(false)
 var gait=load("res://animal_gait.gd")
 var fail=0
 for animal in world.wildlife.entries():
  var pose=world.animal_pose(animal)
  var geometry=gait.geometry(animal,world.animal_metadata[animal.species],pose)
  var i=0
  for polygon in geometry.limbs:
   if Geometry2D.triangulate_polygon(polygon.points).is_empty():
    fail+=1
    print("INVALID_WORLD_STROKE ",animal.species," p=",animal.p," facing=",animal.facing," phase=",animal.gait_phase," moving=",animal.moving," idx=",i," points=",polygon.points)
   i+=1
 print("DIAGNOSE_GAIT_FAILED_POLYGONS ",fail)
 world.queue_free();quit()
