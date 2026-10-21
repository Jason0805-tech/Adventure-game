from pathlib import Path
import shutil,plistlib,subprocess
root=Path(__file__).resolve().parents[3];src=root/'output/adventure game 0.1.5.1';dst=Path('/tmp/Forest-Walk-Playtest.app');shutil.copytree(src/'Forest Wanderer.app',dst,dirs_exist_ok=True)
r=dst/'Contents/Resources';shutil.copyfile(src/'main.gd',r/'main.gd');shutil.copytree(src/'assets',r/'assets',dirs_exist_ok=True)
p=dst/'Contents/Info.plist';info=plistlib.loads(p.read_bytes());info['CFBundleIdentifier']='local.forestwanderer.walkplaytest3';p.write_bytes(plistlib.dumps(info))
p=r/'project.godot';p.write_text(p.read_text().replace('res://main.tscn','res://qa.tscn'))
(r/'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="QA" type="Node2D"]\nscript = ExtResource("1")\n')
(r/'qa.gd').write_text("""extends \"res://main.gd\"
var capture_index := 0
var frame_count := 0
func _ready():
 super._ready()
 DisplayServer.window_set_title(\"Forest Wanderer 0.1.5.1 - Walk Playtest\")
func _process(delta):
 super._process(delta)
 if moving:
  frame_count += 1
  if frame_count % 4 == 0 and capture_index < 80:
   capture.call_deferred()
func capture():
 var index := capture_index
 capture_index += 1
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png(\"/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.1/gait-fix/play-%03d.png\" % index)
""")
subprocess.run(['codesign','--force','--deep','--sign','-',str(dst)],check=True)
