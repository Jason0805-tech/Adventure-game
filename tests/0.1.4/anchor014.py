from pathlib import Path
p=Path('outputs/adventure game 0.1.4/main.gd');s=p.read_text()
s=s.replace('var show_collision := false','var show_collision := false\nvar foot_anchors: Dictionary = {}')
s=s.replace('\tnpc_art = load_grid("res://assets/npcs.png", 2, 2)','''	npc_art = load_grid("res://assets/npcs.png", 2, 2)
	for texture in traveler_art + npc_art:
		var pixels := texture.get_image()
		var total := 0.0
		var weighted_x := 0.0
		for y in range(int(pixels.get_height() * 0.92), pixels.get_height()):
			for x in range(pixels.get_width()):
				var alpha := pixels.get_pixel(x, y).a
				if alpha > 0.5:
					total += alpha
					weighted_x += (x + 0.5) * alpha
		foot_anchors[texture] = weighted_x / total if total > 0 else pixels.get_width() * 0.5''')
s=s.replace('var width := height * tex.get_width() / tex.get_height()\n\treturn Rect2(foot - Vector2(width * 0.5, height), Vector2(width, height))','var scale := height / tex.get_height()\n\tvar width := tex.get_width() * scale\n\tvar pivot_x := float(foot_anchors.get(tex, tex.get_width() * 0.5)) * scale\n\treturn Rect2(foot - Vector2(pivot_x, height), Vector2(width, height))')
p.write_text(s)
