from pathlib import Path
root=Path(__file__).resolve().parents[2];p=root/'output/adventure game 0.1.5/main.gd';s=p.read_text()
s=s.replace('var foot_anchors: Dictionary = {}','var foot_anchors: Dictionary = {}\nvar tree_styles: Dictionary = {}')
s=s.replace('func load_grid(','''func visible_bounds(part: Image) -> Rect2i:
	# Fit to visible paint, not nearly transparent color padding from the atlas.
	# Preserve original pixels and feathered edges inside a six-pixel safety margin.
	part.convert(Image.FORMAT_RGBA8)
	var bytes := part.get_data()
	var width := part.get_width()
	var height := part.get_height()
	var left := width
	var top := height
	var right := -1
	var bottom := -1
	for y in range(0, height, 2):
		for x in range(0, width, 2):
			if bytes[(y * width + x) * 4 + 3] >= 32:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < 0: return Rect2i(0, 0, width, height)
	left = maxi(0, left - 6)
	top = maxi(0, top - 6)
	right = mini(width, right + 8)
	bottom = mini(height, bottom + 8)
	return Rect2i(left, top, right - left, bottom - top)

func load_grid(''',1)
s=s.replace('part.get_region(part.get_used_rect())','part.get_region(visible_bounds(part))')
s=s.replace('variant_art = load_grid("res://assets/tree-variants.png", 3, 2, [0.0, 0.63, 1.0])','variant_art = load_grid("res://assets/tree-variants.png", 3, 2)')
s=s.replace('var variant := seed_value % 6','var variant: int = tree_styles.get(p, seed_value % 6)')
s=s.replace('\ttrees.clear()','\ttree_styles.clear()\n\ttrees.clear()',1)
s=s.replace('\t\ttrees.append(p)','''		var usage := [0, 0, 0, 0, 0, 0]
		for neighbor in trees:
			if neighbor.distance_to(p) < 280:
				usage[int(tree_styles[neighbor])] += 1
		var variant := i % 6
		for k in range(6):
			var candidate := (i + k) % 6
			if usage[candidate] < usage[variant]: variant = candidate
		tree_styles[p] = variant
		trees.append(p)''',1)
# Longer canopies are treated as occluders, while trunks keep their world footprints.
s=s.replace('absf(player.x - p.x) < 65 and p.y - player.y < 150','absf(player.x - p.x) < 86 and p.y - player.y < 185')
p.write_text(s)
