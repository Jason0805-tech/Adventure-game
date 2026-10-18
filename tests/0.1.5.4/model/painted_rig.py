"""Project a shared anatomical rig and composite AI-painted torso cutouts.
The model supplies joint motion and depth only. Visible torso artwork is imagegen
2D paint. Limbs and tools use flat pigment colors/textures, without 3D lighting.
"""
from pathlib import Path
import math,json,time,sys
import numpy as np
from PIL import Image,ImageDraw
import mesh_math as m

ROOT=Path(__file__).resolve().parents[3]
TEST=ROOT/'tests/0.1.5.4'
ASSETS=ROOT/'output/adventure game 0.1.5.4/assets'
W,H,SS=m.W,m.H,m.SS
ANGLES=m.ANGLES
SCALE=m.SCALE
ANCHOR=[48,134]
FOOT_REACH=.45
LEG_LENGTH=.40
HIP_Y=.76
SPRITE_SCALE=.80
STRIDE=4*FOOT_REACH*SCALE*SPRITE_SCALE
# Earth pigments shared with the approved 2D traveler.
m.BASE=np.array([[.85,.58,.14],[.08,.37,.43],[.32,.43,.20],[.09,.32,.33],
                 [.34,.25,.16],[.95,.65,.46],[.12,.20,.18],[.58,.61,.55],
                 [.57,.36,.20],[.17,.28,.16]],dtype=float)
# Coarse filtered pigment, not lighting, is used on the small animated limbs.
if m.TEX is not None:
    m.TEX=[np.asarray(Image.fromarray((np.clip(t,0,2)*127).astype('uint8')).resize((24,24),Image.Resampling.BOX),dtype=float)/127 for t in m.TEX]
    m.TEX=[np.clip(t,.86,1.14) for t in m.TEX]

def foot_cycle(t):
    t=t%1
    if t<.5:return FOOT_REACH-4*FOOT_REACH*t,0.
    q=(t-.5)*2
    return -FOOT_REACH*math.cos(math.pi*q),.085*math.sin(math.pi*q)

def jacket(out,bob):
    y=[.51,.66,.98,1.34,1.46]
    rx=[.34,.36,.35,.27,.20];rz=[.23,.24,.23,.18,.13];n=14
    vv=[np.array([[rx[j]*math.cos(math.tau*i/n),y[j]+bob,rz[j]*math.sin(math.tau*i/n)] for i in range(n)]) for j in range(len(y))]
    for j in range(4):
        for i in range(n):
            k=(i+1)%n
            out.append((np.array([vv[j][i],vv[j+1][i],vv[j][k]]),np.array([[i/n,j/4],[i/n,(j+1)/4],[(i+1)/n,j/4]]),0))
            out.append((np.array([vv[j][k],vv[j+1][i],vv[j+1][k]]),np.array([[(i+1)/n,j/4],[i/n,(j+1)/4],[(i+1)/n,(j+1)/4]]),0))
    m.sphere(out,[0,1.46+bob,0],[.20,.06,.13],0,10,4)
    m.tube(out,[0,.56+bob,.25],[0,1.32+bob,.21],.018,9,6)

def pose(frame,armed=False,use_phase=-1):
    t=frame/8 if frame<8 else 0
    active=frame<8
    bob=-.014*math.cos(2*math.tau*t) if active else 0.
    if use_phase>=0:bob=.025*math.sin(use_phase*math.pi)
    torso=[];limbs=[];leg_info=[]
    jacket(torso,bob)
    m.sphere(torso,[0,1.02+bob,-.315],[.29,.34,.17],2)
    m.tube(torso,[-.27,1.38+bob,-.33],[.27,1.38+bob,-.33],.12,2,12)
    m.tube(torso,[-.282,1.38+bob,-.34],[.282,1.38+bob,-.34],.062,9,10)
    for side in [-1,1]:
        m.tube(torso,[side*.19,1.37+bob,.17],[side*.23,.77+bob,.24],.030,2,8)
    # Facial guides have no modeled nose or detailed eyes; painted art replaces them.
    m.sphere(torso,[0,1.74+bob,.025],[.355,.32,.295],5,14,8)
    for side in [-1,1]:
        m.sphere(torso,[side*.35,1.75+bob,.015],[.058,.072,.052],5,8,4)
        m.sphere(torso,[side*.115,1.785+bob,.299],[.016,.022,.010],6,8,4)
        m.sphere(torso,[side*.28,1.89+bob,.16],[.080,.052,.048],8,8,4)
    m.sphere(torso,[0,1.92+bob,.002],[.387,.258,.326],1,14,8,True)
    m.sphere(torso,[0,1.941+bob,.008],[.39,.07,.338],1,14,5)
    m.sphere(torso,[0,2.23+bob,-.012],[.105,.102,.102],0,10,6)
    for i,side in enumerate([-1,1]):
        z,lift=foot_cycle(t+i*.5) if active else (0.,0.)
        hip=np.array([side*.238,HIP_Y+bob,0.])
        ankle=np.array([side*.238,.12+lift,z])
        knee=m.knee(hip,ankle,LEG_LENGTH,LEG_LENGTH)
        m.tube(limbs,hip,knee,.14,3);m.sphere(limbs,knee,[.143,.14,.143],3,8,4)
        m.tube(limbs,knee,ankle,.13,3)
        m.sphere(limbs,ankle+np.array([0,-.032,.065]),[.17,.105,.25],4,10,5)
        m.sphere(limbs,ankle+np.array([0,-.096,.067]),[.174,.022,.253],6,10,3)
        leg_info.append({'side':side,'hip':hip.tolist(),'knee':knee.tolist(),'ankle':ankle.tolist(),'lift':lift,'z':z})
    for vertices,uv,mat in torso:vertices[:,[0,2]]*=1.5
    right_hand_mesh=[]
    for side in [-1,1]:
        swing=-math.sin(t*math.tau)*.045*side if active else 0.
        shoulder=np.array([side*.282,1.12+bob,0])
        elbow=np.array([side*.43,.91+bob,.04+swing])
        hand=np.array([side*.438,.72+bob,.15+swing])
        if side==-1 and armed:
            elbow=np.array([-.438,.94+bob,.09+swing*.45])
            hand=np.array([-.434,.81+bob,.265+swing*.45])
        if side==-1 and armed and use_phase>=0:
            wind=math.sin(math.pi*use_phase)
            reach=math.sin(math.pi*min(1.,use_phase/0.7)) if use_phase<0.7 else (1-use_phase)/0.3
            elbow[1]+=.12*wind;elbow[2]+=.10*reach
            hand[1]+=.23*wind-.03*reach;hand[2]+=.30*reach
        shoulder[[0,2]]*=1.5
        elbow[0]*=1.25;elbow[2]*=1.5
        hand[0]*=1.25;hand[2]*=1.5
        m.tube(limbs,shoulder,elbow,.13,0);m.sphere(limbs,elbow,[.135,.13,.135],0,8,4)
        m.tube(limbs,elbow,hand,.12,0)
        part=[]
        m.sphere(part,hand,[.105,.093,.108],5,10,5)
        limbs.extend(part)
        if side==-1:
            grip=hand.copy()
            right_hand_mesh=part
    return {'torso':torso,'limbs':limbs,'right_hand_mesh':right_hand_mesh,
            'grip':grip,'legs':leg_info,'bob':bob}

def guide():
    p=pose(8,False)
    sheet=Image.new('RGB',(4*320,4*360),(239,229,200))
    draw=ImageDraw.Draw(sheet)
    for d,yaw in enumerate(ANGLES):
        cell,_=m.render(p['torso'],yaw)
        enlarged=cell.resize((240,320),Image.Resampling.NEAREST)
        x=d%4*320+40;y=d//4*360+6
        sheet.paste(enlarged,(x,y),enlarged)
        draw.text((d%4*320+145,d//4*360+336),str(yaw),fill=(40,60,48))
    sheet.save(TEST/'art/torso-heading-guide.png')
    print('TORSO_GUIDE_READY',flush=True)

def torso_sources():
    source=Image.open(ASSETS/'painted-torso-source.png').convert('RGBA')
    cols,rows=4,4
    result=[]
    # Atlas art is irregularly spaced. Detect the four real paint bands in
    # each column rather than slicing a pompom across nominal equal rows.
    ranges={}
    alpha=np.asarray(source)[:,:,3]
    for col in range(4):
        x0=round(col*source.width/4);x1=round((col+1)*source.width/4)
        occupied=(alpha[:,x0:x1]>80).sum(axis=1)>8
        ys=np.where(occupied)[0]
        groups=np.split(ys,np.where(np.diff(ys)>1)[0]+1)
        groups=[g for g in groups if len(g)>20]
        if len(groups)!=4:raise ValueError("Expected 4 separate torsos in column "+str(col))
        ranges[col]=[(max(0,int(g[0])-5),min(source.height,int(g[-1])+6)) for g in groups]
    p=pose(8,False)
    for d,yaw in enumerate(ANGLES):
        x0=round((d%4)*source.width/4);x1=round((d%4+1)*source.width/4)
        y0,y1=ranges[d%4][d//4]
        cell=source.crop((x0,y0,x1,y1))
        mask=cell.getchannel('A').point(lambda v:255 if v>64 else 0)
        box=mask.getbbox()
        if box is None:raise ValueError('Empty torso at '+str(yaw))
        # Preserve generated brush alpha edges inside a small guard margin.
        box=(max(0,box[0]-2),max(0,box[1]-2),min(cell.width,box[2]+2),min(cell.height,box[3]+2))
        reference,_=m.render(p['torso'],yaw)
        target=reference.getchannel('A').point(lambda v:255 if v>80 else 0).getbbox()
        cropped=cell.crop(box)
        height=target[3]-target[1]
        width=round(cropped.width*height/cropped.height)
        painted=cropped.resize((width,height),Image.Resampling.LANCZOS)
        fitted=Image.new('RGBA',(W,H))
        x=round((target[0]+target[2]-width)/2)
        fitted.alpha_composite(painted,(x,target[1]))
        fitted.save(TEST/'art'/('torso-%03d.png'%yaw))
        result.append(fitted)
    return result

def painted_depth(pixels,guide_depth):
    # Propagate nearby reference depths into irregular painted brush edges.
    # No external dependency is needed, and original model samples stay fixed.
    alpha=np.asarray(pixels.resize((W*SS,H*SS),Image.Resampling.BILINEAR))[:,:,3]
    needed=alpha>30
    filled=guide_depth.copy()
    for _ in range(W+H):
        missing=needed & ~np.isfinite(filled)
        if not missing.any():break
        candidates=np.maximum.reduce([np.roll(filled,1,0),np.roll(filled,-1,0),
                                      np.roll(filled,1,1),np.roll(filled,-1,1)])
        update=~np.isfinite(filled) & np.isfinite(candidates)
        filled[update]=candidates[update]
    if (needed & ~np.isfinite(filled)).any():raise ValueError("Unmapped torso depth")
    return np.where(needed,filled,-np.inf)

def main():
    start=time.time();sources=torso_sources()
    au=Image.new('RGBA',(W*16,H*9));aa=Image.new('RGBA',(W*16,H*9))
    tools=[Image.new('RGBA',(W*16,H*9)) for _ in range(6)]
    hand_debug=Image.new('RGBA',(W*16,H*9))
    info={'columns':16,'angles':ANGLES,'rows':9,'walk_frames':8,'idle_frame':8,'cell':[W,H],
          'anchor':ANCHOR,'style':'AI-painted 2D torso; flat painted articulated limbs',
          'local_right_hand':'negative local X; never mirrored','stride':STRIDE,'frames':[]}
    for frame in range(9):
        poses={armed:pose(frame,armed) for armed in [False,True]}
        for d,yaw in enumerate(ANGLES):
            body=sources[d]
            loc=(d*W,frame*H)
            for armed,atlas in [(False,au),(True,aa)]:
                p=poses[armed]
                dy=-p['bob']*math.cos(m.TILT)*SCALE
                # Only whole-torso bobbing; joints/legs are solved in 3D, never
                # rotating cut-out legs or mirroring the character.
                painted=body.transform((W,H),Image.Transform.AFFINE,(1,0,0,0,1,-dy),Image.Resampling.BICUBIC)
                _,ref_depth=m.render(p['torso'],yaw)
                zbuf=painted_depth(painted,ref_depth)
                visible,full_depth=m.render(p['limbs'],yaw,zbuf)
                final=Image.alpha_composite(painted,visible)
                atlas.paste(final,loc)
                if armed:
                    hxy,hdepth=m.project((p['grip']@m.rotation(yaw).T).reshape(1,3))
                    palm,_=m.render(p['right_hand_mesh'],yaw,zbuf)
                    hand_debug.paste(palm,loc)
                    info['frames'].append({'direction':d,'angle':yaw,'frame':frame,'right_hand':hxy[0].tolist(),
                                          'hand_depth':float(hdepth[0]),'grip_3d':p['grip'].tolist(),
                                          'legs':p['legs'],'body_bob_pixels':dy})
                    for i in range(6):
                        wi,_=m.render(m.weapon(p['grip'],i),yaw,full_depth)
                        tools[i].paste(wi,loc)
        print('PAINTED_RIG_FRAME',frame,'seconds',round(time.time()-start,1),flush=True)
    au.save(ASSETS/'traveler-unarmed-directions.png');aa.save(ASSETS/'traveler-armed-directions.png')
    for i,a in enumerate(tools):a.save(ASSETS/('held-weapon-%d.png'%i))
    hand_debug.save(TEST/'art/right-palm-visible-mask.png')
    (ASSETS/'traveler-directions.json').write_text(json.dumps(info,indent=2))
    p=pose(8,True);m.export_gltf(p['torso']+p['limbs']+m.weapon(p['grip'],0))
    # mesh_math export writes beside itself, inside this version's tests/model.
    for name in ['traveler-reference.gltf','traveler-reference.bin']:
        import shutil
        shutil.copyfile(TEST/'model'/name,ASSETS.parent/'model_reference'/name)
    (TEST/'model/render-report.json').write_text(json.dumps({'seconds':time.time()-start,'directions':16,'walk_frames':8,'style':'painted-2D','stride':STRIDE},indent=2))
    print('PAINTED_ATLASES_COMPLETE',flush=True)

if __name__=='__main__':
    if '--guide' in sys.argv:guide()
    else:main()
