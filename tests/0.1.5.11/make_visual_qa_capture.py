"""Build separate instrumented snapshots for independent front/back visual QA."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
out = root / "tests/0.1.5.11"
for version, name in [("0.1.5.10", "baseline_visual_snapshot_game.gd"), ("0.1.5.11", "visual_snapshot_game.gd")]:
    source = (root / f"output/adventure game {version}/main.gd").read_text()
    source = source.replace("extends Node2D", 'extends "res://../../tests/0.1.5.11/capture_canvas.gd"', 1)
    for call in ["draw_set_transform", "draw_texture_rect_region", "draw_texture_rect", "draw_rect", "draw_circle", "draw_line", "draw_colored_polygon", "draw_polyline", "draw_style_box", "draw_string", "draw_mesh"]:
        source = re.sub(r"\b" + call + r"\(", "record_" + call + "(", source)
    source, count = re.subn(r"(func _draw\(\)(?: -> void)?:\n)", r"\1\trecord_ground_layer(ground_layer, camera)\n", source, count=1)
    assert count == 1
    (out / name).write_text(source)
    print("VISUAL_SNAPSHOT_READY", version, name)
(out / "captures").mkdir(exist_ok=True)
