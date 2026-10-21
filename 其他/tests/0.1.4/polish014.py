from pathlib import Path
p=Path('outputs/adventure game 0.1.4/main.gd');s=p.read_text()
s=s.replace('var moving := false','var moving := false\nvar trail_shapes: Array[PackedVector2Array] = []')
s=s.replace('\trng.seed = 14014','''	rng.seed = 14014
	for route in [PackedVector2Array([Vector2(100,760),Vector2(2030,760)]), PackedVector2Array([Vector2(1700,1310),Vector2(1700,280)]), PackedVector2Array([Vector2(1700,280),Vector2(2070,280)])]:
		var along: Vector2 = (route[1] - route[0]).normalized()
		var across := Vector2(-along.y, along.x)
		var steps := int(route[0].distance_to(route[1]) / 12)
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for i in range(steps + 1):
			var point: Vector2 = route[0].lerp(route[1], float(i) / steps)
			left.append(point + across * rng.randf_range(43, 56))
			right.append(point - across * rng.randf_range(43, 56))
		right.reverse()
		left.append_array(right)
		trail_shapes.append(left)''')
a=s.index('\tvar paths :=');b=s.index('\tfor mark in brush_marks:',a)
s=s[:a]+'''	for shape in trail_shapes:
		draw_colored_polygon(shape, Color("b6ac81"))
		draw_polyline(shape, Color(0.71, 0.70, 0.49, 0.42), 8, true)
''' +s[b:]
s=s.replace('var offset := Vector2(lerpf(28, -34, progress), 16)','var offset := Vector2(lerpf(11, -13, progress), 19)')
s=s.replace('camera = player - screen * 0.5','camera = player - screen * Vector2(0.5, 0.67)')
p.write_text(s)
