from pathlib import Path
import json,math
import numpy as np
from PIL import Image
import painted_rig as r
a=r.ASSETS
meta=json.loads((a/'traveler-directions.json').read_text())
checks=0
def expect(ok,name):
    global checks
    checks+=1
    if not ok:raise AssertionError(name)
expect(meta['angles']==r.ANGLES and len(r.ANGLES)==16,'All requested headings and exact diagonals')
expect(meta['walk_frames']==8 and meta['idle_frame']==8,'Eight walk poses and one idle pose')
expect(abs(meta['stride']-60.48)<1e-8,'Movement/gait stride calibration')
for name in ['traveler-unarmed-directions','traveler-armed-directions',*[f'held-weapon-{i}' for i in range(6)]]:
    im=np.asarray(Image.open(a/(name+'.png')))
    expect(im.shape==(1440,1536,4),'Aligned RGBA atlas dimensions '+name)
    for f in range(9):
        for d in range(16):
            c=im[f*160:(f+1)*160,d*96:(d+1)*96]
            expect(max(c[:3,:,3].max(),c[-3:,:,3].max(),c[:,:3,3].max(),c[:,-3:,3].max())<40,'No cell bleed '+name+str((f,d)))
            if name.startswith('traveler'):
                expect((c[:,:,3]>160).sum()>600,'Complete painted body '+str((f,d)))
palm=np.asarray(Image.open(r.TEST/'art/right-palm-visible-mask.png'))
body=np.asarray(Image.open(a/'traveler-armed-directions.png'))
visible_contacts=0
for entry in meta['frames']:
    f=entry['frame'];d=entry['direction'];yaw=entry['angle']
    p=r.pose(f,True);grip=p['grip']
    expect(grip[0]<0,'Anatomical right hand never flips')
    expect(np.linalg.norm(grip-entry['grip_3d'])<1e-8,'Metadata uses actual rig grip')
    xy,_=r.m.project((grip@r.m.rotation(yaw).T).reshape(1,3))
    expect(np.linalg.norm(xy[0]-entry['right_hand'])<1e-8,'Palm and weapon share projected anchor')
    # A hand hidden by the body remains hidden; no alternate left-hand art.
    x,y=np.rint(xy[0]).astype(int)
    mask=palm[f*160:(f+1)*160,d*96:(d+1)*96,3]
    if mask[max(0,y-1):y+2,max(0,x-1):x+2].max()>64:
        visible_contacts+=1
        expect(body[f*160+y,d*96+x,3]>64,'Visible palm belongs to body')
    for leg in p['legs']:
        hip,knee,ankle=[np.array(leg[n]) for n in ['hip','knee','ankle']]
        expect(abs(np.linalg.norm(knee-hip)-r.LEG_LENGTH)<1e-7 and abs(np.linalg.norm(ankle-knee)-r.LEG_LENGTH)<1e-7,'Fixed leg lengths')
        expect(abs(knee[0]-hip[0])<1e-7,'Knee stays in sagittal plane; no sideways propeller motion')
    for index in range(6):
        # All six weapon constructors take the same immutable right-hand joint.
        mesh=r.m.weapon(grip,index)
        points=np.concatenate([v for v,uv,mat in mesh])
        expect(np.min(np.linalg.norm(points-grip,axis=1))<.15,'Handle physically intersects same palm '+str(index))
expect(visible_contacts>45,'Visible hand contact checked across turn/walk poses')
for t in [.01,.07,.13,.19,.26,.33,.41,.48]:
    z0,lift0=r.foot_cycle(t);z1,lift1=r.foot_cycle(t+.5)
    expect(lift0==0 and lift1>0,'One support foot and opposite swing foot')
    expect(abs(z0-r.foot_cycle(t+.001)[0]-.0018)<1e-8,'Support foot advances smoothly in model')
for d in range(16):
    c0=body[:160,d*96:(d+1)*96]
    c4=body[4*160:5*160,d*96:(d+1)*96]
    expect(not np.array_equal(c0,c4),'Opposite foot phase actually changes each view')
source=(a.parent/'main.gd').read_text()
expect('const AVATAR_SCALE := 0.80' in source and 'const WALK_STRIDE := 60.48' in source,'Game uses validated scale/cadence')
report={'checks':checks,'failures':0,'headings':16,'walk_frames':8,'visible_grip_checks':visible_contacts,
        'same_anatomical_right_hand':True,'fixed_leg_lengths':True,'native_gui_manually_played':False}
(r.TEST/'model/validation.json').write_text(json.dumps(report,indent=2))
print('PAINTED_AVATAR_RESULT:',checks,'checks, 0 failures; visible grips:',visible_contacts)
