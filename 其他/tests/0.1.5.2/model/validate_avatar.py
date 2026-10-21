from pathlib import Path
import importlib.util,json,math
import numpy as np
from PIL import Image
p=Path(__file__).parent
spec=importlib.util.spec_from_file_location('avatar_renderer',p/'render_avatar.py');renderer=importlib.util.module_from_spec(spec);spec.loader.exec_module(renderer)
a=renderer.ASSETS
meta=json.loads((a/'traveler-directions.json').read_text())
checks=0
def expect(ok,title):
 global checks
 checks+=1
 if not ok:raise AssertionError(title)
expect(meta['angles']==[0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330],'Requested headings and exact diagonals exist')
expect(meta['columns']==16 and meta['walk_frames']==8 and meta['idle_frame']==8,'Atlas layout')
for name in ['traveler-unarmed-directions','traveler-armed-directions',*[f'held-weapon-{i}' for i in range(6)]]:
 pixels=np.asarray(Image.open(a/(name+'.png')))
 expect(pixels.shape==(1152,1536,4),'All bodies and weapons share dimensions')
 for frame in range(9):
  for d in range(16):
   cell=pixels[frame*128:(frame+1)*128,d*96:(d+1)*96]
   expect(cell[:3,:,3].max()<32 and cell[-3:,:,3].max()<32 and cell[:,:3,3].max()<32 and cell[:,-3:,3].max()<32,'No neighboring cell bleed')
   if name.startswith('traveler-'):expect((cell[:,:,3]>128).sum()>300,'Body frame has complete visible content')
blade=np.asarray(Image.open(a/'held-weapon-0.png'))
near_side=meta['angles'].index(90)
for frame in range(8):
 cell=blade[frame*128:(frame+1)*128,near_side*96:(near_side+1)*96,3]
 yy,xx=np.where(cell>128)
 expect(len(yy)>35 and np.ptp(yy)>20,'Side-view blade retains visible thickness and length')
for frame in meta['frames']:
 grip=np.array(frame['grip_3d'])
 expect(grip[0]<0,'Same anatomical right hand for every heading and pose')
 xy,_=renderer.project((grip@renderer.rotation(frame['angle']).T).reshape(1,3))
 expect(np.linalg.norm(xy[0]-frame['right_hand'])<1e-6,'Weapon grip agrees with body projection')
for frame in range(8):
 t=frame/8;bob=-.025*math.cos(t*math.tau*2)
 for i,side in enumerate([-1,1]):
  z,lift=renderer.foot_cycle(t+i*.5)
  hip=np.array([side*.14,.85+bob,0]);ankle=np.array([side*.14,.13+lift,z]);joint=renderer.knee(hip,ankle)
  expect(abs(np.linalg.norm(joint-hip)-.38)<1e-6 and abs(np.linalg.norm(ankle-joint)-.38)<1e-6,'Leg segment lengths stay fixed')
  expect(abs(joint[0]-hip[0])<1e-6,'Knees bend forward, never sideways')
# Verify a complete cycle rather than pose counts alone.
for phase in [.01,.07,.13,.19,.26,.33,.41,.48]:
 x0,lift0=renderer.foot_cycle(phase);x1,lift1=renderer.foot_cycle(phase+.5)
 expect(lift0==0 and lift1>0,'One supporting foot and one swinging foot')
 expect(abs(x0+renderer.foot_cycle(phase+.001)[0]-2*x0+.00120)<1e-8,'Supporting foot advances uniformly backward relative to body')
game_source=(renderer.ROOT/'output/adventure game 0.1.5.2/main.gd').read_text()
expect('const WALK_STRIDE := 39.744' in game_source and abs(1.2*renderer.SCALE*.72-39.744)<1e-6,'Game cadence matches the model stance travel')
mesh,grip=renderer.pose(8,True)
renderer.export_gltf(mesh+renderer.weapon(grip,0))
(p/'validation.json').write_text(json.dumps({'checks':checks,'failures':0,'headings':16,'walk_frames':8,'idle_frames':1,'same_right_hand':True,'fixed_segment_lengths':True},indent=2))
print('AVATAR_RESULT:',checks,'checks, 0 failures')
