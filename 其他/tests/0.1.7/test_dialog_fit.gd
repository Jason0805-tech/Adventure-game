extends SceneTree
# Every conversation line must fit inside the 950-wide paper panel (30 px margin)
# and above the Continue button (row limit 14, as in 0.1.6), on desktop font sizes.
func _initialize()->void:call_deferred("run")
func run()->void:
	var g:Variant=load("res://main.tscn").instantiate();g.resource_seed=164;root.add_child(g);g.set_process(false);await process_frame
	var bad:=[]
	for who in [g.npc_home,g.npc_position,g.beacon.BEACON_POS]:
		g.dialog="";g.interaction_cooldown=0;g.player=who+Vector2(0,60) if who==g.beacon.BEACON_POS else who+Vector2(34,0)
		g.interact()
		var lines:PackedStringArray=g.dialog.split("\n")
		for i in range(lines.size()):
			var w:float=g.font.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,21 if i==0 else 17).x
			if w>950-60:bad.append("%s line %d width %d" % [lines[0],i,w])
		if lines.size()>14:bad.append("%s has %d lines" % [lines[0],lines.size()])
		print("DIALOG ",lines[0]," lines=",lines.size())
	print("DIALOG_FIT ",JSON.stringify({"problems":bad,"passed":bad.is_empty()}))
	quit()
