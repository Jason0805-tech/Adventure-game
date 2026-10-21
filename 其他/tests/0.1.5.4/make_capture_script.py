from pathlib import Path
root=Path(__file__).resolve().parents[2];source=(root/'output/adventure game 0.1.5.4/main.gd').read_text()
source=source.replace('extends Node2D','extends "res://../../tests/0.1.5.4/capture_canvas.gd"',1)
for name in ['draw_set_transform','draw_texture_rect_region','draw_texture_rect','draw_rect','draw_circle','draw_line','draw_colored_polygon','draw_polyline','draw_style_box','draw_string']:
 source=source.replace(name+'(','record_'+name+'(')
(root/'tests/0.1.5.4/snapshot_game.gd').write_text(source)
(root/'tests/0.1.5.4/captures').mkdir(exist_ok=True)
