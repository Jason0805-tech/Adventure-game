extends SceneTree
# Measures the avatar's surviving opacity from actual Canvas texture commands,
# independently of the runtime depth ordering implementation.
const OUT="res://../../tests/0.1.5.9/"
var game:Variant
var images:Dictionary={}
var checks:=0
var failures:=0
var results:Array=[]
var baseline:=false
var only_texture_keys:Array=[]
var only_world_origins:Array=[]
func _initialize()->void:call_deferred("run")
func pixels(path:String)->Image:
	if not images.has(path):images[path]=Image.load_from_file(path)
	return images[path]
func alpha_at(command:Dictionary,screen:Vector2)->float:
	var transform:Array=command.transform
	var p:Vector2=(screen-Vector2(transform[0],transform[1])).rotated(-float(transform[2]))/Vector2(transform[3],transform[4])
	var a:Array=command.rect
	var rect:=Rect2(a[0],a[1],a[2],a[3])
	if not rect.has_point(p):return 0.0
	var uv:Vector2=(p-rect.position)/rect.size
	var image:Image=pixels(command.texture.path)
	var source:=Rect2(Vector2.ZERO,Vector2(image.get_width(),image.get_height()))
	if command.has("source"):
		var s:Array=command.source;source=Rect2(s[0],s[1],s[2],s[3])
	var q:Vector2=source.position+source.size*uv
	return image.get_pixel(clampi(int(q.x),0,image.get_width()-1),clampi(int(q.y),0,image.get_height()-1)).a*float(command.color[3])
func save_world_capture(name:String)->void:
	var original:Array=game.commands.duplicate()
	var world:Array=[]
	for command in original:
		var t:Array=command.transform
		if absf(float(t[0]))<0.0001 and absf(float(t[1]))<0.0001:break
		world.append(command)
	game.commands=world
	game.save_capture(name,440,340)
	game.commands=original
func measure(label:String,save:bool=false)->void:
	game.camera=game.player-Vector2(220,230)
	game.reset_capture();game._draw()
	var avatar_key:String=str(game.avatar_unarmed.get_instance_id())
	var actor_command:Dictionary={}
	var after:Array=[]
	var actor_seen:=false
	for command in game.commands:
		if command.kind!="texture":continue
		if str(command.texture.path).ends_with("-"+avatar_key+".png"):
			actor_command=command;actor_seen=true;continue
		if actor_seen:
			var eligible:bool=only_texture_keys.is_empty()
			for key in only_texture_keys:
				if str(command.texture.path).ends_with("-"+str(key)+".png"):eligible=true
			if eligible and not only_world_origins.is_empty():
				eligible=false
				var world_origin:Vector2=Vector2(command.transform[0],command.transform[1])+game.camera
				for origin in only_world_origins:
					if world_origin.distance_to(origin)<0.1:eligible=true
			if eligible:after.append(command)
	assert(not actor_command.is_empty())
	var samples:=0;var hidden:=0;var surviving:=0.0;var min_surviving:=1.0;var hidden_samples:Array=[]
	var rect:Array=actor_command.rect
	var source:Array=actor_command.source
	var actor_image:Image=pixels(actor_command.texture.path)
	for y in range(20,123,5):
		for x in range(12,85,5):
			if actor_image.get_pixel(int(source[0])+x,int(source[1])+y).a<0.85:continue
			var p:=Vector2(rect[0]+x/96.0*rect[2],rect[1]+y/160.0*rect[3])+Vector2(actor_command.transform[0],actor_command.transform[1])
			var survival:=1.0
			for command in after:survival*=1.0-alpha_at(command,p)
			samples+=1;surviving+=survival;min_surviving=minf(min_surviving,survival)
			if survival<0.75:
				hidden+=1;hidden_samples.append({"avatar_source_local":[x,y],"screen":[p.x,p.y],"survival":survival})
	var average:float=surviving/maxi(1,samples)
	checks+=1
	if average<0.985 or hidden>0:failures+=1
	results.append({"label":label,"player":[game.player.x,game.player.y],"opaque_avatar_samples":samples,"samples_losing_over_25_percent_alpha":hidden,"mean_surviving_opacity":average,"minimum_surviving_opacity":min_surviving,"hidden_samples":hidden_samples,"pass":average>=0.985 and hidden==0})
	if save:save_world_capture(("baseline-" if baseline else "corrected-")+label)
func run()->void:
	baseline="baseline" in OS.get_cmdline_user_args()
	var script:String="baseline_snapshot_game.gd" if baseline else "snapshot_game.gd"
	game=load(OUT+script).new();game.resource_seed=159;root.add_child(game);game.set_process(false)
	for child in game.get_children():child.set_process(false)
	game.npc_home=Vector2(50,1450);game.npc_position=Vector2(90,1450);game.message_time=0
	game.show_collision=false;game.day_time=30
	# This route is defined from the visible house location, independent of any
	# depth metadata: walking north from the open path must leave the complete
	# actor in front of the facade, stairs and its painted ground vegetation.
	for x in range(250,451,10):
		game.player=Vector2(x,760);game.facing=Vector2.UP
		game.move_player(Vector2.UP,2.4)
		assert(game.walkable(game.player))
		measure("cabin-front-%d"%x,x in [280,310,320,360,370,400,440])
	var summary:Dictionary={"version":"0.1.5.9","baseline":baseline,"checks":checks,"failures":failures,"results":results,"method":"21 actual northward player movement routes along cabin frontage; original avatar alpha samples replayed through actual ordered Canvas texture commands. At a legal front contact, head and torso must survive the complete facade/ground vegetation paint."}
	var path:String=OUT+("baseline-front-visibility.json" if baseline else "front-visibility-results.json")
	var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(summary,"\t"));file.close()
	print("ACTUAL_FRONT_VISIBILITY ",JSON.stringify(summary))
	game.queue_free();quit(0 if baseline or failures==0 else 1)
