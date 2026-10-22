extends RefCounted
const Data=preload("res://item_data.gd")
const PAPER=Color("e9dcb6")

func base_rect(game:Variant)->Rect2:
	return Rect2(Vector2(24,16),game.get_viewport_rect().size-Vector2(48,32))
func bag_slot_rect(game:Variant,index:int)->Rect2:
	return Rect2(base_rect(game).position+Vector2(24+(index%6)*106,105+floori(index/6.0)*106),Vector2(99,99))
func bag_hotbar_rect(game:Variant,index:int)->Rect2:
	return Rect2(base_rect(game).position+Vector2(24+index*106,559),Vector2(99,99))
func text(game:Variant,p:Vector2,value:String,size:int=26,color:Color=Color("35483d"))->void:
	game.label_at(p,value,size,color)
func button(game:Variant,rect:Rect2,value:String,id:String,enabled:bool=true)->void:
	game.ui_button(rect,value,id,enabled)
func status(game:Variant,p:Vector2,title:String,value:float,icon:int,color:Color,bar_width:float=215.0)->void:
	if icon>=0:game.draw_texture_rect(game.status_art[icon],Rect2(p+Vector2(0,3),Vector2(37,37)),false)
	else:game.draw_sanity_mark(p+Vector2(18,20),16.0)
	text(game,p+Vector2(47,28),"%s %d"%[title,floori(value) if icon<0 else ceili(value)],25)
	game.paper_panel(Rect2(p+Vector2(47,37),Vector2(bar_width,13)),Color("948e6e"),4)
	game.draw_rect(Rect2(p+Vector2(48,38),Vector2((bar_width-2)*clampf(value/100.0,0,1),11)),color)
func toast_room(game:Variant,screen:Vector2)->float:
	# The centred toast must end before the right-hand button column (Map).
	var width:float=minf(650,screen.x-700)
	var regions:Dictionary=game.mobile.hit_regions
	if regions.has("map"):width=minf(width,2.0*(Rect2(regions.map).position.x-16.0)-screen.x)
	return maxf(260.0,width)
func draw(game:Variant,screen:Vector2)->void:
	if screen.x<screen.y:
		game.draw_rect(Rect2(Vector2.ZERO,screen),Color("203d37"))
		text(game,Vector2(60,screen.y*.45),"Turn your phone sideways",36,Color("f0e5c6"))
		text(game,Vector2(60,screen.y*.45+54),"The forest is paused while you rotate.",24,Color("e9dcb6"));return
	if game.wildlife!=null and game.active_exploration():
		for animal in game.wildlife.entries():game.draw_animal_status(animal)
	game.paper_panel(Rect2(16,12,screen.x-32,112),PAPER)
	var first:float=minf(370,screen.x*.28)
	var column:float=(screen.x-first-30)/3.0
	var bar_width:float=minf(215,column-65)
	text(game,Vector2(32,45),"FOREST WANDERER",28 if screen.x>=1230 else 22)
	text(game,Vector2(32,78),"v0.1.7-alpha.1  ·  THE OLD BEACON" if screen.x>=1230 else "v0.1.7-alpha.1",20,Color("657259"))
	status(game,Vector2(first,24),"Health",game.health,0,Color("b7674c"),bar_width)
	status(game,Vector2(first+column,24),"Fullness",game.fullness,1,Color("bc984e"),bar_width)
	status(game,Vector2(first+column*2,24),"Sanity",game.sanity,-1,Color("827b9e"),bar_width)
	var timer:String=("Dawn in " if game.phase=="night" else "Night in ")+game.clock_text()
	text(game,Vector2(first,105),"Day %d   ·   Beacon %d / 3   ·   Bag %d / 24"%[game.night,game.beacon.parts_found(),game.bag.used_slots()],23)
	text(game,Vector2(32,107),timer,23,Color("875c31"))
	text(game,Vector2(first+column*2,105),"RESTING" if game.survival.resting else game.survival.level(game.sanity),22,Color("827b9e"))
	var modal:bool=game.inventory or game.crafting or game.paused or not str(game.dialog).is_empty() or not game.active_exploration()
	if not modal:
		game.mobile.draw(game)
		var sky:Dictionary=game.lighting.atmosphere(game)
		var y:float=150 if screen.x>=1320 else 280
		game.paper_panel(Rect2(28,y,285,56),PAPER,8)
		text(game,Vector2(42,y+37),str(sky.title),26)
		# Keep the goal clear of the centred toast.
		var goal:String=game.beacon.objective(game)
		var toast_width:float=toast_room(game,screen)
		var room:float=(screen.x-toast_width)*.5-40
		var one_line:float=game.font.get_string_size(goal,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+32
		if one_line<=room:
			game.paper_panel(Rect2(28,y+64,one_line,44),PAPER,8)
			text(game,Vector2(44,y+94),goal,22,Color("6a4a22"))
		else:
			# Narrow phones: wrap onto two lines instead of clipping under the toast.
			game.paper_panel(Rect2(28,y+64,room,74),PAPER,8)
			game.draw_wrapped_text(goal,Vector2(44,y+92),room-32,20,2)
		if game.message_time>0:
			var width:float=toast_width
			var toast_y:float=142 if screen.x>=1320 and game.mobile.css_height>=360 else 280
			game.paper_panel(Rect2((screen.x-width)*.5,toast_y,width,94),PAPER,8)
			game.draw_wrapped_text(game.message,Vector2((screen.x-width)*.5+16,toast_y+34),width-32,24,2)
		return
	game.draw_rect(Rect2(Vector2.ZERO,screen),Color(0.02,0.06,0.07,0.6))
	var panel:=base_rect(game)
	game.paper_panel(panel,PAPER,16)
	var b:=panel.position
	if game.paused:
		text(game,b+Vector2(36,72),"PAUSED",38)
		text(game,b+Vector2(36,140),"Time, animals and actions are paused.",27)
		text(game,b+Vector2(36,194),"Closing or refreshing the page starts a new run.",25)
		button(game,Rect2(b+Vector2(36,520),Vector2(260,100)),"Resume","resume")
	elif game.inventory:draw_bag(game,panel)
	elif game.crafting:draw_craft(game,panel)
	elif not str(game.dialog).is_empty():
		var lines:PackedStringArray=str(game.dialog).split("\n")
		var yy:float=58
		for i in range(lines.size()):
			var line:String=lines[i]
			line=line.replace("Press C","Tap Craft").replace("Hold E","Hold Gather").replace("Press E","Tap Gather").replace("press Space or click","hold Use").replace("B opens","Bag opens").replace("T toggles it.","Tap Torch to toggle it.").replace("T lights a torch.","Torch lights a torch.").replace("H uses medicine","Heal uses medicine")
			text(game,b+Vector2(30,yy),line,29 if i==0 else 23)
			yy+=36 if i==0 else 30
		button(game,Rect2(panel.end-Vector2(275,118),Vector2(245,100)),"Continue","close")
	else:
		var title:String="NIGHT %d SURVIVED"%game.night
		if game.won:title="BEACON LIT - YOU ESCAPED!"
		if game.lost:title="GAME OVER"
		text(game,b+Vector2(36,76),title,36)
		game.draw_wrapped_text(game.result_text,b+Vector2(36,150),panel.size.x-72,27,3)
		text(game,b+Vector2(36,290),"Health %d   ·   Fullness %d   ·   Sanity %d"%[game.health,game.fullness,game.sanity],28)
		text(game,b+Vector2(36,350),"Nights survived: %d   ·   Beacon parts %d / 3"%[game.survived,game.beacon.parts_found()],28)
		button(game,Rect2(b+Vector2(36,520),Vector2(350,100)),"New run" if game.won or game.lost else "Continue to morning","restart" if game.won or game.lost else "morning")
func draw_bag(game:Variant,panel:Rect2)->void:
	var b:=panel.position
	text(game,b+Vector2(24,40),"BACKPACK  ·  %d / 24"%game.bag.used_slots(),30)
	text(game,b+Vector2(24,77),"Tap an item, then a quick slot to equip. Drag to rearrange.",23)
	button(game,Rect2(panel.end.x-180,b.y+8,160,99),"Close","close")
	for i in range(24):game.draw_item_slot(bag_slot_rect(game,i),game.bag.slots[i],i==game.selected_slot)
	text(game,b+Vector2(24,548),"QUICK SLOTS",22,Color("657259"))
	for i in range(6):
		var r:=bag_hotbar_rect(game,i)
		game.draw_item_slot(r,game.bag.item_by_uid(game.hotbar[i]),i==game.active_hotbar,i)
	var x:float=b.x+680
	var width:float=panel.end.x-x-22
	var selected:Dictionary=game.bag.slots[game.selected_slot] if game.selected_slot>=0 else {}
	if selected.is_empty():
		game.draw_wrapped_text("Choose an item to inspect it. Tools and food can be assigned to quick slots.",Vector2(x,b.y+150),width,25,5)
	else:
		text(game,Vector2(x,b.y+145),Data.label(selected.id),28)
		text(game,Vector2(x,b.y+185),"Quantity: %d"%selected.qty,25)
		game.draw_wrapped_text(str(Data.info(selected.id).get("description","")),Vector2(x,b.y+230),width,24,4)
		if selected.has("durability"):text(game,Vector2(x,b.y+370),"Durability %d / %d"%[selected.durability,Data.info(selected.id).durability],24)
		if selected.has("fuel"):text(game,Vector2(x,b.y+370),"Fuel: %d seconds"%selected.fuel,24)
	button(game,Rect2(x,b.y+405,width,99),"Sort backpack","sort")
	button(game,Rect2(x,b.y+516,width*.48,99),"Drop","drop_selected",not selected.is_empty())
	var repair:bool=selected.has("durability") and int(selected.get("durability",0))<int(Data.info(selected.get("id","")).get("durability",0)) and game.nearby_bench()>=0
	button(game,Rect2(x+width*.52,b.y+516,width*.48,99),"Repair","repair",repair)
	text(game,Vector2(x,b.y+650),"Repair: 2 branches, 1 rock, 1 fiber",19)
func draw_craft(game:Variant,panel:Rect2)->void:
	var b:=panel.position
	text(game,b+Vector2(24,48),"CRAFTING  ·  "+("WORKBENCH" if game.bench_available() else "FIELD"),30)
	button(game,Rect2(panel.end.x-180,b.y+8,160,99),"Close","close")
	var recipes:Array[int]=game.visible_recipes()
	var pages:int=maxi(1,ceili(recipes.size()/4.0))
	game.crafting_page=clampi(game.crafting_page,0,pages-1)
	for row in range(4):
		var index:int=game.crafting_page*4+row
		if index>=recipes.size():break
		var ri:int=recipes[index]
		var r:Dictionary=Data.RECIPES[ri]
		var y:float=b.y+110+row*110
		game.draw_item_icon(r.id,Rect2(b.x+24,y+12,76,76))
		text(game,Vector2(b.x+120,y+35),Data.label(r.id),28)
		game.draw_wrapped_text(game.ingredient_summary(r.cost),Vector2(b.x+120,y+70),panel.size.x-370,23,2)
		var allowed:bool=game.bag.can_pay(r.cost) and (game.bag.used_slots()<24 or not str(r.get("upgrade","")).is_empty())
		button(game,Rect2(panel.end.x-185,y,160,99),"Craft","craft_"+str(ri),allowed)
	button(game,Rect2(b.x+24,panel.end.y-112,200,99),"Previous","previous_page",game.crafting_page>0)
	text(game,Vector2(b.x+260,panel.end.y-52),"Page %d / %d"%[game.crafting_page+1,pages],26)
	button(game,Rect2(panel.end.x-225,panel.end.y-112,200,99),"Next","next_page",game.crafting_page+1<pages)
