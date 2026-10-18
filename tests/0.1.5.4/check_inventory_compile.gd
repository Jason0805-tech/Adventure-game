extends SceneTree
func _initialize():
 var bag=load("res://inventory.gd").new()
 bag.add("branch",23)
 print("INVENTORY_COMPILE_OK ",bag.count("branch")," ",bag.validate())
 quit()
