extends SceneTree
const OUT="res://../../tests/0.1.6.2/"
var game:Variant
func _initialize()->void:call_deferred("run")
func run()->void:
	game=load(OUT+"snapshot_game.gd").new();game.resource_seed=162
	root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.camera=Vector2.ZERO
	# Original complete painting versus the moving UV skin, at the same scale.
	for frame in range(24):
		game.reset_capture();game.record_draw_rect(Rect2(0,0,1000,1220),Color("bdc99f"))
		game.label_at(Vector2(30,32),"ORIGINAL PAINT",23)
		game.label_at(Vector2(530,32),"SAME PAINT - CONTINUOUS WALK",23)
		for row in range(5):
			var species:String=["rabbit","deer","fox","wolf","bear"][row]
			game.label_at(Vector2(25,80+row*225),species.capitalize(),19)
			var animal:Dictionary={"uid":row+1,"species":species,"p":Vector2(260,235+row*225),"facing":Vector2.RIGHT,"moving":false,"gait_phase":0.0,"state":"idle","alpha":1.0,"hitflash":0.0,"frame":0}
			var pose:Dictionary=game.animal_pose(animal);pose.scale=.8
			game.AnimalGait.draw(game,animal,game.animal_atlases[species],pose,game.animal_metadata[species])
			animal.p.x=760;animal.moving=true;animal.gait_phase=float(frame)/24
			game.AnimalGait.draw(game,animal,game.animal_atlases[species],pose,game.animal_metadata[species])
		game.label_at(Vector2(24,1200),"Actual release drawing commands / software replay / native source PNGs unchanged",14)
		game.save_capture("art-review-%02d"%frame,1000,1220)
	# Every authored heading, using the actual in-game render scale at 2x view.
	game.reset_capture();game.record_draw_rect(Rect2(0,0,1920,1240),Color("bdc99f"))
	game.record_draw_set_transform(Vector2.ZERO,0,Vector2(2,2))
	for row in range(5):
		for direction in range(8):
			var species:String=["rabbit","deer","fox","wolf","bear"][row]
			var radians:float=deg_to_rad(float(direction*45))
			var animal:Dictionary={"uid":row*8+direction+1,"species":species,"p":Vector2(60+direction*120,100+row*120),"facing":Vector2(sin(radians),cos(radians)),"moving":true,"gait_phase":.2,"state":"wander","alpha":1.0,"hitflash":0.0,"frame":0}
			game.draw_animal_shadow(animal);game.draw_animal(animal)
			game.label_at(animal.p+Vector2(-35,22),species.capitalize()+" "+str(direction*45),12)
	game.save_capture("all-painted-headings",1920,1240)
	print("PAINTED_ART_REVIEW_CAPTURED 24 phases + 40 headings")
	game.queue_free();quit()
