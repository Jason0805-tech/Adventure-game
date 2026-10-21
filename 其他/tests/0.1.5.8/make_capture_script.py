"""Record the actual release Canvas calls without changing runtime source."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
version = "0.1.5.8"
source = (root / f"output/adventure game {version}/main.gd").read_text()
source = source.replace("extends Node2D", f'extends "res://../../tests/{version}/capture_canvas.gd"', 1)
canvas_calls = [
    "draw_set_transform", "draw_texture_rect_region", "draw_texture_rect",
    "draw_rect", "draw_circle", "draw_line", "draw_colored_polygon",
    "draw_polyline", "draw_style_box", "draw_string", "draw_mesh",
]
for name in canvas_calls:
    source = re.sub(r"\b" + name + r"\(", "record_" + name + "(", source)
if "var ground_layer" in source:
    source, inserted = re.subn(
        r"(func _draw\(\)(?: -> void)?:\n)",
        r"\1\trecord_ground_layer(ground_layer, camera)\n",
        source,
        count=1,
    )
    if inserted != 1:
        raise RuntimeError("Could not insert the runtime ground-layer capture")
destination = root / f"tests/{version}"
(destination / "snapshot_game.gd").write_text(source)
(destination / "captures").mkdir(exist_ok=True)
print("CAPTURE_SCRIPT_READY", destination / "snapshot_game.gd")
