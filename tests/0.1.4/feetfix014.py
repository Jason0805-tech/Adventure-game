from pathlib import Path
p=Path('outputs/adventure game 0.1.4/main.gd');s=p.read_text()
s=s.replace('var total := 0.0\n\t\tvar weighted_x := 0.0\n\t\tfor y in range(int(pixels.get_height() * 0.92), pixels.get_height()):','''var sole_y := pixels.get_height() - 1
		for y in range(pixels.get_height() - 1, -1, -1):
			var solid := false
			for x in range(pixels.get_width()):
				if pixels.get_pixel(x, y).a > 0.5:
					solid = true
					break
			if solid:
				sole_y = y
				break
		var total := 0.0
		var weighted_x := 0.0
		for y in range(maxi(0, sole_y - int(pixels.get_height() * 0.08)), sole_y + 1):''')
s=s.replace('foot_anchors[texture] = weighted_x / total if total > 0 else pixels.get_width() * 0.5','foot_anchors[texture] = Vector2(weighted_x / total if total > 0 else pixels.get_width() * 0.5, sole_y + 1)')
s=s.replace('var pivot_x := float(foot_anchors.get(tex, tex.get_width() * 0.5)) * scale\n\treturn Rect2(foot - Vector2(pivot_x, height), Vector2(width, height))','var pivot: Vector2 = foot_anchors.get(tex, Vector2(tex.get_width() * 0.5, tex.get_height()))\n\treturn Rect2(foot - pivot * scale, Vector2(width, height))')
p.write_text(s)
p=Path('outputs/adventure game 0.1.4/art_tests.gd');s=p.read_text().replace('var pivot: float =','var pivot: Vector2 =').replace('absf(rect.position.x + pivot - foot.x) < 0.01 and absf(rect.end.y - foot.y) < 0.01','(rect.position + pivot).distance_to(foot) < 0.01');p.write_text(s)
