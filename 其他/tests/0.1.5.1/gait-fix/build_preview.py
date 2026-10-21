from pathlib import Path
import shutil,plistlib,subprocess
root=Path(__file__).resolve().parents[3]; src=root/'output/adventure game 0.1.5.1';dst=Path('/tmp/Forest-Gait-Review.app');shutil.copytree(src/'Forest Wanderer.app',dst,dirs_exist_ok=True)
r=dst/'Contents/Resources';shutil.copyfile(src/'main.gd',r/'main.gd');shutil.copyfile(src/'assets/traveler-leg-rig.png',r/'assets/traveler-leg-rig.png')
p=dst/'Contents/Info.plist';info=plistlib.loads(p.read_bytes());info['CFBundleIdentifier']='local.forestwanderer.gaitreview1';p.write_bytes(plistlib.dumps(info))
p=r/'project.godot';p.write_text(p.read_text().replace('res://main.tscn','res://qa.tscn'))
(r/'qa.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://qa.gd" id="1"]\n[node name="QA" type="Node2D"]\nscript = ExtResource("1")\n')
(r/'qa.gd').write_text('''extends "res://main.gd"
var review_clock := 0.0
var captured := 0
func _ready():
 super._ready()
 camera = Vector2.ZERO
func _process(delta):
 review_clock += delta
 walk_distance = fposmod(review_clock * SPEED, WALK_STRIDE)
 gait_weight = 1.0
 moving = true
 queue_redraw()
 if captured < 16:
  capture.call_deferred()
func capture():
 await RenderingServer.frame_post_draw
 if captured >= 16: return
 get_viewport().get_texture().get_image().save_png("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.1/gait-fix/continuous-%02d.png" % captured)
 captured += 1
func _draw():
 if walk_art.is_empty(): return
 draw_rect(Rect2(0,0,1100,720),Color("91ad79"))
 draw_string(font,Vector2(24,32),"CONTINUOUS GAIT / 120 px per second / equal left and right steps",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("213d33"))
 var dirs = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]
 var phase_saved = walk_distance
 for d in range(4):
  facing = dirs[d]
  for j in range(8):
   walk_distance = WALK_STRIDE * j / 8.0
   var pos = Vector2(65+j*138,165+d*160)
   draw_ellipse_shadow(pos)
   draw_traveler_rig(pos)
  walk_distance = phase_saved
  # The last column continuously animates alongside the fixed phase samples.
  draw_rect(Rect2(1000,55+d*160,100,120),Color("b8c99b"))
  draw_traveler_rig(Vector2(1050,160+d*160))
 walk_distance = phase_saved
''')
subprocess.run(['codesign','--force','--deep','--sign','-',str(dst)],check=True)
