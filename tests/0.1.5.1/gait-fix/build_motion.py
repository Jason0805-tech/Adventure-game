from pathlib import Path
import shutil,plistlib,subprocess
root=Path(__file__).resolve().parents[3];src=root/'output/adventure game 0.1.5.1';dst=Path('/tmp/Forest-Painted-Step-Check.app');shutil.copytree(src/'Forest Wanderer.app',dst,dirs_exist_ok=True)
r=dst/'Contents/Resources';shutil.copyfile(src/'main.gd',r/'main.gd');shutil.copytree(src/'assets',r/'assets',dirs_exist_ok=True)
p=dst/'Contents/Info.plist';info=plistlib.loads(p.read_bytes());info['CFBundleIdentifier']='local.forestwanderer.paintedstep2';p.write_bytes(plistlib.dumps(info))
p=r/'project.godot';p.write_text(p.read_text().replace('res://main.tscn','res://qa.tscn'))
(r/'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="QA" type="Node2D"]\nscript = ExtResource("1")\n')
(r/'qa.gd').write_text('''extends "res://main.gd"
var sample := 0
func _ready():
 super._ready()
 set_process(false)
 camera = Vector2.ZERO
 capture.call_deferred()
func capture():
 for i in range(32):
  sample = i
  moving = true
  walk_distance = WALK_STRIDE * float(i%8) / 8.0
  queue_redraw()
  await RenderingServer.frame_post_draw
  await RenderingServer.frame_post_draw
  get_viewport().get_texture().get_image().get_region(Rect2i(0,0,800,400)).save_png("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.1/gait-fix/motion-%02d.png" % i)
 print("MOTION_CAPTURE_COMPLETE")
func _draw():
 if walk_art.is_empty(): return
 draw_rect(Rect2(0,0,1100,720),Color("91ad79"))
 draw_string(font,Vector2(20,30),"Painted walk cycle - motion review",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("213d33"))
 var dirs = [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]
 var names = ["Right","Down","Left","Up"]
 for d in range(4):
  facing = dirs[d]
  var p := Vector2(100 + d*190,190)
  draw_ellipse_shadow(p)
  draw_traveler(p)
  draw_string(font,p+Vector2(-25,35),names[d],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("213d33"))
 # Eight ordered samples, for comparing continuity around the loop.
 var phase_saved := walk_distance
 facing = Vector2.RIGHT
 for j in range(8):
  walk_distance = WALK_STRIDE * j / 8.0
  draw_traveler(Vector2(45+j*100,350))
 walk_distance = phase_saved
''')
subprocess.run(['codesign','--force','--deep','--sign','-',str(dst)],check=True)
