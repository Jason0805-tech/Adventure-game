from pathlib import Path
root=Path(__file__).resolve().parents[3];p=root/'output/adventure game 0.1.5.1/main.gd';s=(root/'tests/0.1.5.1/gait-fix/main-before.gd').read_text()
s=s.replace('const SPEED := 240.0','const SPEED := 110.0').replace('const WALK_STRIDE := 128.0','const WALK_STRIDE := 64.0\nvar step_art: Array[Texture2D] = []')
s=s.replace('\twalk_art.clear()', '\tstep_art.clear()\n\tfor name in ["step-pass-a", "step-contact-b", "step-pass-b"]:\n\t\tstep_art.append_array(load_grid("res://assets/" + name + ".png", 1, 1))\n\twalk_art.clear()')
a=s.index('\t\tvar frame := direction_index(facing)',s.index('func person'));b=s.index('\n\t\tdraw_arc',a)
s=s[:a]+'\t\tdraw_traveler(p)'+s[b:]
insert='''# Whole painted poses, with a fixed upper body. No rotated or stretched leg pieces.
func draw_traveler(p: Vector2) -> void:
	var direction := direction_index(facing)
	var side := direction == 1 or direction == 2
	var back := direction == 3
	var key := int(walk_distance / WALK_STRIDE * 4.0) % 4
	var body := walk_art[12 if side else (18 if back else 0)]
	var lower: Texture2D
	var cut := 0.0
	var flip_lower := false
	var lower_pivot := 0.5
	if side:
		if not moving:
			lower = traveler_art[2]
			cut = 0.77
			lower_pivot = 0.59
		elif key == 0:
			lower = walk_art[12]
			cut = 0.74
			lower_pivot = 0.58
		elif key == 1:
			lower = step_art[0]
			cut = 0.78
			lower_pivot = 0.60
		elif key == 2:
			lower = step_art[1]
			cut = 0.78
			lower_pivot = 0.60
		else:
			lower = step_art[2]
			cut = 0.76
			lower_pivot = 0.60
	else:
		if not moving or key % 2 == 1:
			lower = traveler_art[3 if back else 0]
			cut = 0.77 if back else 0.75
		else:
			lower = walk_art[18 if back else 0]
			cut = 0.72
			flip_lower = key == 2
	var lower_size := lower.get_size()
	var lower_height := lower_size.y * (1.0 - cut)
	var scale := 19.0 / lower_height
	var direction_scale := -1.0 if direction == 1 else 1.0
	draw_set_transform(p - camera,0,Vector2(direction_scale * (-1.0 if flip_lower else 1.0),1))
	draw_texture_rect_region(lower,Rect2(Vector2(-lower_size.x * lower_pivot * scale,-19),Vector2(lower_size.x * scale,19)),Rect2(Vector2(0,lower_size.y*cut),Vector2(lower_size.x,lower_height)))
	draw_set_transform(p - camera,0,Vector2(direction_scale,1))
	var body_cut := 366.0 if side else (338.0 if back else 348.0)
	var body_scale := 56.0 / body_cut
	var pivot := 188.0 if side else (149.0 if back else 153.0)
	draw_texture_rect_region(body,Rect2(Vector2(-pivot*body_scale,-73),Vector2(body.get_width()*body_scale,56)),Rect2(0,0,body.get_width(),body_cut))
	draw_set_transform(-camera)

'''
s=s.replace('func person(',insert+'func person(');p.write_text(s)
