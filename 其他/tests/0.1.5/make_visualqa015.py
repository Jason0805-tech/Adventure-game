from pathlib import Path
import shutil, plistlib, subprocess
src=Path(__file__).resolve().parents[2] / 'output/adventure game 0.1.5/Forest Wanderer.app'; dst=Path('/tmp/Forest-Art-Check-015.app')
shutil.copytree(src,dst,dirs_exist_ok=True)
p=dst/'Contents/Info.plist'; info=plistlib.loads(p.read_bytes());info['CFBundleIdentifier']='local.forestwanderer.artcheck015c';info['CFBundleName']='Forest Art Check';p.write_bytes(plistlib.dumps(info))
r=dst/'Contents/Resources'
p=r/'project.godot';p.write_text(p.read_text().replace('run/main_scene="res://main.tscn"','run/main_scene="res://qa.tscn"'))
(r/'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="QA" type="Node"]\nscript = ExtResource("1")\n')
(r/'qa.gd').write_text('''extends Node
func _ready():
 call_deferred("capture")
func capture():
 var game = load("res://main.tscn").instantiate()
 add_child(game)
 game.set_process(false)
 game.camera = game.player - Vector2(550,482.4)
 game.camera.x = 0
 game.message_time = 0
 for state in ["day", "sunset", "craft", "night", "left", "right", "up", "lake", "collision"]:
  game.day_time = 76 if state == "sunset" else 20
  game.crafting = state == "craft"
  game.phase = "choice" if state == "night" else "day"
  if state in ["left", "right", "up"]:
   game.facing = Vector2.LEFT if state == "left" else (Vector2.RIGHT if state == "right" else Vector2.UP)
  if state in ["lake", "collision"]:
   game.player = Vector2(1040,650)
   game.camera = Vector2(490,170)
  game.show_collision = state == "collision"
  game.queue_redraw()
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().save_png("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5/art015-" + state + ".png")
 print("VISUAL_CAPTURE_COMPLETE")
''')
subprocess.run(['xattr','-dr','com.apple.FinderInfo',str(dst)],check=False)
subprocess.run(['codesign','--force','--deep','--sign','-',str(dst)],check=True)
