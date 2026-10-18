from pathlib import Path
p=Path(__file__).resolve().parents[2]/'output/adventure game 0.1.5.2/main.gd';s=p.read_text()
pos=s.index('func draw_survival_ui(')
s=s[:pos]+'''func painted_status(origin: Vector2, title: String, value: float, icon: int, color: Color) -> void:
	draw_texture_rect(status_art[icon],Rect2(origin + Vector2(0,5),Vector2(29,29)),false)
	label_at(origin + Vector2(39,17),title,15,Color("53634d"))
	label_at(origin + Vector2(222,17),"%d / 100" % int(ceil(clampf(value,0,100))),15,Color("53634d"))
	var bar := Rect2(origin + Vector2(39,23),Vector2(257,14))
	paper_panel(bar.grow(2),Color("8e9877"),4)
	var width := bar.size.x * clampf(value / 100.0,0,1)
	if width > 0:
		var outline := PackedVector2Array([bar.position,bar.position+Vector2(width,1),bar.position+Vector2(width,12),bar.position+Vector2(width*0.67,14),bar.position+Vector2(width*0.32,12),bar.position+Vector2(0,14)])
		draw_colored_polygon(outline,color)
		for i in range(7):
			var x := (i + 0.5) * width / 7.0
			draw_line(bar.position+Vector2(x-4,4+i%2),bar.position+Vector2(minf(width,x+6),5+i%2),Color(1,0.94,0.73,0.10),2,true)

''' +s[pos:]
a=s.index('\tpaper_panel(Rect2(12, 8, screen.x - 24, 108)',s.index('func draw_survival_ui'));b=s.index('\tvar map_pos :=',a)
s=s[:a]+'''\tpaper_panel(Rect2(12,8,screen.x-24,135),Color("e9dcb6"))
	label_at(Vector2(24,32),"FOREST WANDERER",25)
	label_at(Vector2(335,31),"0.1.5.2  /  THREE NIGHTS",16,Color("657259"))
	label_at(Vector2(screen.x-265,32),("NIGHT IN "+clock_text()) if phase=="day" else ("NIGHT "+str(night)),22,Color("875c31"))
	painted_status(Vector2(24,43),"Health",health,0,Color("b7674c"))
	painted_status(Vector2(354,43),"Fullness",float(fullness),1,Color("bc984e"))
	label_at(Vector2(696,66),"Survived %d / 3   |   %s %d" % [survived,"Day" if phase=="day" else "Night",night],16)
	label_at(Vector2(696,92),"Threat %d   |   Power %d" % [night*3,power],16)
	label_at(Vector2(24,125),"Branches %d   Rocks %d   Fibers %d   |   Bag %d/10   |   Magic stones %d   Medicine %d" % [branches,rocks,ropes,branches+rocks+ropes,magic_stones,medicine],17)
''' +s[b:]
s=s.replace('var map_pos := Vector2(screen.x - 180, 136)','var map_pos := Vector2(screen.x - 180, 169)')
s=s.replace('"WASD / Arrows: Move    E: Interact    B: Bag    C: Craft    Esc: Pause    F3: Hitboxes"','"WASD / Arrows: Move    E: Gather / Talk    B: Bag    C: Craft    H: Heal    Esc: Pause    F3: Hitboxes"')
s=s.replace('Vector2(24, 149)','Vector2(24, 172)').replace('Vector2(24, 176)','Vector2(24, 199)').replace('Rect2(24, 193, 225, 32)','Rect2(24, 216, 225, 32)').replace('217 - sin','240 - sin')
s=s.replace('Rect2(270, 125, 570, 31)','Rect2(270, 155, 570, 31)').replace('Vector2(283, 147)','Vector2(283, 177)')
s=s.replace('"Ropes"','"Fibers"').replace('"rope": "Ropes"','"rope": "Fibers"')
s=s.replace('food_check() + " (Warnings only.)"','food_check()').replace('"Fullness gives warnings only in this version."','"Low power can injure you. Starving drains health in daylight."')
s=s.replace('ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "B / Esc  Close", "close")','ui_button(Rect2(base + Vector2(30, 463), Vector2(220, 42)), "B / Esc  Close", "close")\n\t\tui_button(Rect2(base + Vector2(464, 463), Vector2(220,42)), "H  Use medicine", "heal",medicine > 0 and health < 100)')
s=s.replace('"Power %d   |   Fullness %d / 100   |   Stones %d   Medicine %d" % [power, fullness, magic_stones, medicine]','"Health %d/100 | Fullness %d/100 | Stones %d | Medicine %d" % [int(health), fullness, magic_stones, medicine]')
s=s.replace('Gather branches, rocks and ropes during the day.','Gather shrubs, rock outcrops and fiber grass.').replace('Press C to craft weapons. Their power adds up.','Press C to craft. Berry shrubs restore fullness.')
s=s.replace('If power is too low: use a magic stone, then medicine.','Low power: a stone protects you; medicine treats injuries.')
p.write_text(s)
