from pathlib import Path
import shutil
root=Path(__file__).resolve().parents[3]; p=root/'output/adventure game 0.1.5.1'
shutil.copyfile('/Users/jasonsmacair/.codex/generated_images/01a12370-5b35-7eb2-809e-f354f97a3872/exec-c756b3a4-063b-45e9-ad2d-0439f79d41aa.png',p/'assets/traveler-leg-rig.png')
f=p/'main.gd'; s=f.read_text().replace('const SPEED := 240.0','const SPEED := 120.0').replace('const WALK_STRIDE := 128.0','const WALK_STRIDE := 56.0\nvar gait_weight := 0.0\nvar leg_art: Array[Texture2D] = []')
s=s.replace('\twalk_art.clear()', '\tleg_art = load_grid("res://assets/traveler-leg-rig.png", 3, 1)\n\twalk_art.clear()')
s=s.replace('\tvar screen := get_viewport_rect().size\n\tcamera = player', '\tif not paused:\n\t\tgait_weight = lerpf(gait_weight, 1.0 if moving else 0.0, 1.0 - exp(-dt * 22.0))\n\tvar screen := get_viewport_rect().size\n\tcamera = player',1)
a=s.index('\t\tvar frame := direction_index(facing)',s.index('func person'));b=s.index('\n\t\tdraw_arc',a)
s=s[:a]+'\t\tdraw_traveler_rig(p)'+s[b:]
insert='''# Continuous two-leg cycle: one foot stays planted while the other swings.
# The stance travels 28 px relative to the body over 28 px of world travel.
# Both legs use the exact same curve, separated by half a cycle.
func gait_sample(cycle: float) -> Vector2:
	var t := fposmod(cycle, 1.0)
	if t < 0.5:
		return Vector2(14.0 - 56.0 * t, 0.0)
	var swing := (t - 0.5) * 2.0
	return Vector2(-14.0 * cos(PI * swing), 5.0 * sin(PI * swing))

func draw_rig_leg(texture: Texture2D, hip: Vector2, sole: Vector2, side: bool, tint: Color) -> void:
	var size := texture.get_size()
	var boot_height := 6.0
	var ankle := sole - Vector2(0, boot_height * 0.8)
	var axis := ankle - hip
	var normal := Vector2(axis.y, -axis.x).normalized() * (3.7 if side else 4.2)
	var vertices := PackedVector2Array([hip - normal, hip + normal, ankle + normal, ankle - normal])
	# The side-view trouser occupies the left 55% of the source, before the toe.
	var right_uv := 0.56 if side else 1.0
	var uvs := PackedVector2Array([Vector2(0,0),Vector2(right_uv,0),Vector2(right_uv,0.65),Vector2(0,0.65)])
	draw_polygon(vertices, PackedColorArray([tint]), uvs, texture)
	var boot_width := 12.0 if side else 9.0
	var offset := 4.0 if side else boot_width * 0.5
	draw_texture_rect_region(texture, Rect2(sole - Vector2(offset, boot_height), Vector2(boot_width, boot_height)), Rect2(Vector2(0, size.y * 0.64), Vector2(size.x, size.y * 0.36)), tint)

func draw_traveler_rig(p: Vector2) -> void:
	var direction := direction_index(facing)
	var side := direction == 1 or direction == 2
	var back := direction == 3
	var source := walk_art[12 if side else (18 if back else 0)]
	var texture := leg_art[1 if side else (2 if back else 0)]
	var cycle := walk_distance / WALK_STRIDE
	var weight := gait_weight
	var bob := (cos(cycle * TAU * 2.0) - 1.0) * 0.35 * weight
	var hips := [Vector2(-1.5 if side else -6.0, -17 + bob), Vector2(1.5 if side else 6.0, -17 + bob)]
	var soles: Array[Vector2] = []
	for i in range(2):
		var step := gait_sample(cycle + i * 0.5) * weight
		if side:
			soles.append(Vector2(step.x, -step.y))
		else:
			soles.append(Vector2(hips[i].x, step.x * (-0.30 if back else 0.30) - step.y))
	# Mirroring the complete rig keeps every attachment in the same coordinate space.
	draw_set_transform(p - camera, 0, Vector2(-1 if direction == 1 else 1, 1))
	var order := [0,1]
	if not side and soles[0].y > soles[1].y: order = [1,0]
	for i in order:
		draw_rig_leg(texture, hips[i], soles[i], side, Color(0.80,0.85,0.83) if side and i == 0 else Color.WHITE)
	# One fixed upper-body painting: no head resizing or per-frame re-centering.
	var cut := 366.0 if side else (338.0 if back else 348.0)
	var height := 56.0
	var scale := height / cut
	var pivot := 188.0 if side else (149.0 if back else 153.0)
	draw_texture_rect_region(source, Rect2(Vector2(-pivot * scale, -17 - height + bob),Vector2(source.get_width() * scale, height)),Rect2(0,0,source.get_width(),cut))
	draw_set_transform(-camera)

'''
s=s.replace('func person(',insert+'func person(')
f.write_text(s)
