"""Prove the HD atlas change preserves the validated body, hand, and gait."""
from pathlib import Path
import ast,json,hashlib
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
T=Path(__file__).resolve().parent
A=ROOT/'output/adventure game 0.1.5.10/assets'
OLD=ROOT/'output/adventure game 0.1.5.9/assets'
checks=[]
def check(ok,label):
    checks.append({'label':label,'passed':bool(ok)})
    if not ok: print('FAIL',label)
def equal_scaled(a,b,scale=2.):
    return np.allclose(np.asarray(a),np.asarray(b)*scale,rtol=0.,atol=1e-9)
def function_ast(path,name):
    node=ast.parse(path.read_text())
    return ast.dump(next(n for n in node.body if isinstance(n,ast.FunctionDef) and n.name==name),include_attributes=False)

for source,names in [('painted_rig.py',['foot_cycle','jacket','pose','painted_depth']),('mesh_math.py',['sphere','tube','knee','weapon','rotation','render']),('render_tools_npcs.py',['tool','swing_angle','rotated_tool','compose'])]:
    for name in names:
        check(function_ast(T/source,name)==function_ast(ROOT/'tests/0.1.5.5/model'/source,name),'unchanged model/render function '+source+':'+name)

normal=json.loads((A/'traveler-directions.json').read_text());old=json.loads((OLD/'traveler-directions.json').read_text())
check(normal['cell']==[192,320] and normal['anchor']==[96,268],'normal cell and anchor doubled')
check(normal['stride']==old['stride'],'world stride exactly unchanged')
check(normal['angles']==old['angles'] and normal['walk_frames']==old['walk_frames'],'headings and walk frame counts unchanged')
check(normal['local_right_hand']==old['local_right_hand'],'anatomical right-hand convention unchanged')
check(len(normal['frames'])==144,'all 16 headings x 9 normal frames are represented')
for n,o in zip(normal['frames'],old['frames']):
    key=f"normal angle{n['angle']} frame{n['frame']}"
    check(n['legs']==o['legs'] and n['grip_3d']==o['grip_3d'],key+' exact model positions and 3D grip')
    check(equal_scaled(n['right_hand'],o['right_hand']),key+' doubled hand projection preserves normalized grip')
    check(abs(n['hand_depth']-o['hand_depth'])<1e-12,key+' unchanged hand depth')
    check(abs(n['body_bob_pixels']-o['body_bob_pixels']*2)<1e-12,key+' doubled raster bob preserves world movement')

use=json.loads((A/'tool-use-meta.json').read_text());old_use=json.loads((OLD/'tool-use-meta.json').read_text())
check(len(use)==96 and use.keys()==old_use.keys(),'all 16 headings x 6 action frames retained')
for k,n in use.items():
    o=old_use[k]
    check(n['grip_3d']==o['grip_3d'],k+' exact action grip model position')
    check(equal_scaled(n['right_hand'],o['right_hand']),k+' action hand normalized position unchanged')
    check(equal_scaled(n['rod_tip'],o['rod_tip']),k+' action rod tip normalized position unchanged')

npc=json.loads((T/'model/npc-motion-meta.json').read_text());old_npc=json.loads((ROOT/'tests/0.1.5.5/model/npc-motion-meta.json').read_text())
check(npc==old_npc,'all 144 NPC model poses and heading order byte-equivalent as JSON')

sizes={}
for name in ['traveler-unarmed-directions.png','traveler-armed-directions.png']+[f'held-weapon-{i}.png' for i in range(9)]: sizes[name]=(3072,2880)
for name in ['traveler-use-directions.png']+[f'held-use-weapon-{i}.png' for i in range(9)]: sizes[name]=(6144,2304)
for name in ['npc-rowan-directions.png','npc-ash-directions.png','npc-rowan-lantern.png']: sizes[name]=(1536,2880)
records=[]
for name,expected in sizes.items():
    im=Image.open(A/name);old_im=Image.open(OLD/name)
    check(im.size==expected and im.size==(old_im.width*2,old_im.height*2),name+' true doubled output canvas')
    check(im.mode=='RGBA',name+' retains alpha')
    records.append({'file':name,'size':list(im.size),'previous_size':list(old_im.size),'sha256':hashlib.sha256((A/name).read_bytes()).hexdigest()})
for name in ['painted-torso-source.png','npc-torso-source.png','paint-materials.png']:
    check((A/name).read_bytes()==(OLD/name).read_bytes(),'same approved painted source '+name)
report={'checks':len(checks),'failures':sum(not c['passed'] for c in checks),'normal_cell':[192,320],'normal_anchor':[96,268],'action_cell':[384,384],'action_anchor':[192,332],'source_art_preserved':True,'world_stride':normal['stride'],'rig_scale_only':True,'pngs':records,'results':checks}
(T/'hd-actor-verification.json').write_text(json.dumps(report,indent=2))
print('HD_ACTOR_VERIFICATION',report['checks'],'checks',report['failures'],'failures',len(records),'atlas PNGs')
raise SystemExit(1 if report['failures'] else 0)
