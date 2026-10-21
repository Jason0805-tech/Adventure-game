extends SceneTree
# Regression for 问题报告/不能退出对话.png: holding the key that closes a
# conversation must not reopen it (E) or swing the held tool (Space).
var checks:=0
var failures:Array[String]=[]
var g:Variant
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error("FAIL "+label)
func key(code:int,pressed:bool)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func frames(n:int)->void:
	for i in range(n):g._process(1.0/60.0)
func run()->void:
	Input.use_accumulated_input=false
	g=load("res://main.tscn").instantiate();g.resource_seed=164;root.add_child(g);g.set_process(false);await process_frame
	g.wildlife.animals.clear();g.phase="day"
	g.player=g.npc_position+Vector2(34,0)
	check(str(g.nearest_target().get("kind",""))=="scout","player stands beside Ash")
	key(KEY_E,true);frames(1);key(KEY_E,false);frames(2)
	check(not g.dialog.is_empty(),"E opens Ash's conversation")
	key(KEY_E,true);frames(1)
	check(g.dialog.is_empty(),"E press closes the conversation")
	frames(40)
	check(g.dialog.is_empty(),"holding E after closing does not reopen the conversation")
	key(KEY_E,false);frames(3)
	check(g.dialog.is_empty(),"releasing E keeps the conversation closed")
	key(KEY_E,true);frames(1);key(KEY_E,false);frames(2)
	check(not g.dialog.is_empty(),"a new E press can talk again")
	g.bag.add("sword",1);g.sanitize_hotbar()
	key(KEY_SPACE,true);frames(1)
	check(g.dialog.is_empty(),"Space closes the conversation")
	frames(20)
	check(g.action.is_empty(),"holding Space after closing does not swing the tool")
	key(KEY_SPACE,false);frames(3)
	g.crafting=true;frames(1);key(KEY_E,true);frames(2);key(KEY_C,true);frames(1);key(KEY_C,false);frames(30)
	check(not g.crafting and g.dialog.is_empty(),"closing any menu with E held does not trigger a new interaction")
	key(KEY_E,false);frames(2)
	print(JSON.stringify({"suite":"dialog_close","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
