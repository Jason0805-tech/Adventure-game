extends SceneTree
const SkinRig=preload("res://animal_gait.gd")
const REPORT="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.2/gait-uv/runtime-benchmark.json"
class Stage extends Node2D:
	var metadata:Dictionary
	var atlases:Dictionary={}
	var records:Array=[]
	var frame:=0
	func _ready():
		metadata=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
		for species in metadata.species:
			var image:=Image.load_from_file(metadata.species[species].path)
			image.generate_mipmaps();atlases[species]=ImageTexture.create_from_image(image)
		queue_redraw()
	func _process(_dt):queue_redraw()
	func _draw():
		var started:int=Time.get_ticks_usec();var count:=0
		for species in metadata.species:
			var m:Dictionary=metadata.species[species]
			for direction in range(8):
				var pose:Dictionary={"direction":direction,"scale":float(m.world_height)/float(m.reference_height_px),"anchor":Vector2(192,320),"source":Rect2(direction*384,0,384,384)}
				var animal:Dictionary={"uid":str(species)+str(direction),"species":species,"p":Vector2(500,400),"gait_phase":fposmod(float(frame)*.103,1.0),"moving":true}
				SkinRig.draw(self,animal,atlases[species],pose,m)
				count+=1
		var elapsed:float=float(Time.get_ticks_usec()-started)/1000.0
		if frame>=2:records.append(elapsed)
		frame+=1
		if frame>=12:
			var total:float=0
			for sample in records:total+=sample
			var result:Dictionary={"description":"Actual native Canvas CPU submission, headless; not a GPU frame-rate measurement","headings_per_frame":40,"warmup_frames":2,"measured_frames":records.size(),"native_draws":frame*40,"ms_per_40_animals":records,"runtime_boolean_compiles":SkinRig._topology.size(),"compiled_entries_resident":SkinRig._compiled.size(),"mean_ms_per_40":total/records.size(),"mean_ms_per_animal":total/records.size()/40}
			var file:=FileAccess.open(REPORT,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
			print("SKIN_NATIVE_BENCHMARK ",JSON.stringify(result));get_tree().quit()
func _initialize():root.add_child.call_deferred(Stage.new())
