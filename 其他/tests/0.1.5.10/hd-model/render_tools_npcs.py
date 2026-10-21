from pathlib import Path
import math,json,time
import numpy as np
from PIL import Image
import painted_rig as r
m=r.m
ROOT=r.ROOT;A=r.ASSETS;T=r.TEST
base_weapon=m.weapon
NPC_ANGLES=[0,45,90,135,180,225,270,315]
PLAYER_BASE=m.BASE.copy()
m.BASE=np.vstack([m.BASE,[.37,.51,.56]])
PLAYER_BASE=m.BASE.copy()

def tool(grip,index):
    if index<6:return base_weapon(grip,index)
    if index==8:
        result=base_weapon(grip,2)
        return [(v,uv,10 if mat==7 else mat) for v,uv,mat in result]
    out=[]
    if index==6:
        axis=np.array([0.,.985,.172])
        m.tube(out,grip-axis*.09,grip+axis*.54,.030,4,8)
        head=grip+axis*.50
        m.tube(out,head+np.array([-.29,-.12,0]),head+np.array([0,.02,0]),.038,7,8)
        m.tube(out,head+np.array([0,.02,0]),head+np.array([.29,-.12,0]),.038,7,8)
    elif index==7:
        tip=grip+np.array([0,1.20,.43])
        m.tube(out,grip-np.array([0,.10,.036]),tip,.018,4,8)
        m.sphere(out,grip+np.array([.055,.12,.05]),[.055,.060,.055],7,8,4)
    elif index==9:
        center=grip+np.array([0,-.18,.015])
        m.tube(out,grip,center+np.array([0,.10,0]),.018,6,8)
        m.box(out,center,[.15,.20,.12],0)
        for dx in [-.09,.09]:
            m.tube(out,center+np.array([dx,-.12,0]),center+np.array([dx,.12,0]),.02,6,6)
        m.sphere(out,center+np.array([0,.13,0]),[.12,.035,.085],6,10,3)
        m.sphere(out,center+np.array([0,-.13,0]),[.12,.035,.085],6,10,3)
    return out

def swing_angle(p):
    def ease(t):return t*t*(3-2*t)
    if p<=.25:return -.52*ease(p/.25)
    if p<=.70:return -.52+2.02*ease((p-.25)/.45)
    return 1.5*(1-ease((p-.70)/.30))
def rotated_tool(grip,index,phase):
    mesh=tool(grip,index)
    a=swing_angle(phase)
    c,s=math.cos(a),math.sin(a)
    rot=np.array([[1,0,0],[0,c,-s],[0,s,c]])
    return [((v-grip)@rot.T+grip,uv,mat) for v,uv,mat in mesh],rot

def fit_sheet(path,angles):
    source=Image.open(path).convert('RGBA');alpha=np.asarray(source)[:,:,3]
    ranges={}
    for col in range(4):
        x0=round(col*source.width/4);x1=round((col+1)*source.width/4)
        yy=np.where((alpha[:,x0:x1]>80).sum(axis=1)>8)[0]
        groups=np.split(yy,np.where(np.diff(yy)>1)[0]+1)
        groups=[g for g in groups if len(g)>20]
        if len(groups)!=4:raise ValueError((col,len(groups)))
        ranges[col]=[(max(0,int(g[0])-5),min(source.height,int(g[-1])+6)) for g in groups]
    sources=[]
    for d,yaw in enumerate(angles):
        x0=round((d%4)*source.width/4);x1=round((d%4+1)*source.width/4)
        y0,y1=ranges[d%4][d//4]
        cell=source.crop((x0,y0,x1,y1))
        box=cell.getchannel('A').point(lambda v:255 if v>64 else 0).getbbox()
        cropped=cell.crop((max(0,box[0]-2),max(0,box[1]-2),min(cell.width,box[2]+2),min(cell.height,box[3]+2)))
        ref,_=m.render(r.pose(8,False)['torso'],yaw)
        bbox=ref.getchannel('A').point(lambda v:255 if v>80 else 0).getbbox()
        height=bbox[3]-bbox[1];width=round(cropped.width*height/cropped.height)
        if width>m.W-16:
            height=round(height*(m.W-16)/width);width=m.W-16
        painted=cropped.resize((width,height),Image.Resampling.LANCZOS)
        fitted=Image.new('RGBA',(m.W,m.H))
        fitted.alpha_composite(painted,(round((bbox[0]+bbox[2]-width)/2),bbox[3]-height))
        sources.append(fitted)
    return sources

def compose(body,p,yaw):
    dy=-p['bob']*math.cos(m.TILT)*m.SCALE
    body=body.transform((m.W,m.H),Image.Transform.AFFINE,(1,0,0,0,1,-dy),Image.Resampling.BICUBIC)
    _,depth=m.render(p['torso'],yaw)
    depth=r.painted_depth(body,depth)
    limbs,depth=m.render(p['limbs'],yaw,depth)
    return Image.alpha_composite(body,limbs),depth

def player_tools():
    start=time.time()
    for i in [6,7,8]:
        atlas=Image.new('RGBA',(192*16,320*9))
        for f in range(9):
            p=r.pose(f,True)
            for d,yaw in enumerate(r.ANGLES):
                # Existing painted bodies already match this reference.
                _,depth=m.render(p['torso']+p['limbs'],yaw)
                im,_=m.render(tool(p['grip'],i),yaw,depth)
                atlas.paste(im,(d*192,f*320))
        atlas.save(A/('held-weapon-%d.png'%i))
    bodies=r.torso_sources()
    m.W=r.W=384;m.H=r.H=384
    expanded=[]
    for body in bodies:
        im=Image.new('RGBA',(384,384));im.alpha_composite(body,(96,64));expanded.append(im)
    body_atlas=Image.new('RGBA',(384*16,384*6))
    tools=[Image.new('RGBA',body_atlas.size) for i in range(9)]
    palms=Image.new('RGBA',body_atlas.size)
    metadata={}
    for f in range(6):
        phase=f/5
        p=r.pose(8,True,phase)
        for d,yaw in enumerate(r.ANGLES):
            body,depth=compose(expanded[d],p,yaw)
            pos=(d*384,f*384);body_atlas.paste(body,pos)
            hand,hd=m.project((p['grip']@m.rotation(yaw).T).reshape(1,3))
            palm,_=m.render(p['right_hand_mesh'],yaw)
            palms.paste(palm,pos)
            entry={'angle':yaw,'frame':f,'right_hand':hand[0].tolist(),'grip_3d':p['grip'].tolist()}
            for i in range(9):
                mesh,rot=rotated_tool(p['grip'],i,phase)
                im,_=m.render(mesh,yaw,depth)
                tools[i].paste(im,pos)
                if i==7:
                    tip=np.array([0,1.20,.43])@rot.T+p['grip']
                    xy,_=m.project((tip@m.rotation(yaw).T).reshape(1,3))
                    entry['rod_tip']=xy[0].tolist()
            metadata['%d_%d'%(d,f)]=entry
        print('TOOL_ACTION_FRAME',f,'seconds',round(time.time()-start,1),flush=True)
    body_atlas.save(A/'traveler-use-directions.png')
    for i,im in enumerate(tools):im.save(A/('held-use-weapon-%d.png'%i))
    (A/'tool-use-meta.json').write_text(json.dumps(metadata,indent=2))
    palms.save(T/'art/use-right-hand-mask.png')
    m.W=r.W=192;m.H=r.H=320
    print('PLAYER_TOOL_ACTIONS_COMPLETE',flush=True)

def npcs():
    start=time.time();sources=fit_sheet(A/'npc-torso-source.png',NPC_ANGLES*2)
    metadata=[]
    for name,start_index in [('rowan',0),('ash',8)]:
        m.BASE=PLAYER_BASE.copy()
        m.BASE[0]=[.76,.38,.14] if name=='rowan' else [.43,.48,.24]
        m.BASE[3]=[.10,.25,.27] if name=='rowan' else [.16,.25,.29]
        m.BASE[5]=[.92,.65,.46]
        atlas=Image.new('RGBA',(192*8,320*9));lantern=Image.new('RGBA',atlas.size)
        for f in range(9):
            p=r.pose(f,name=='rowan')
            for d,yaw in enumerate(NPC_ANGLES):
                body,depth=compose(sources[start_index+d],p,yaw)
                atlas.paste(body,(d*192,f*320))
                if name=='rowan':
                    im,_=m.render(tool(p['grip'],9),yaw,depth);lantern.paste(im,(d*192,f*320))
                metadata.append({'actor':name,'frame':f,'angle':yaw,'legs':p['legs']})
        atlas.save(A/('npc-%s-directions.png'%name))
        if name=='rowan':lantern.save(A/'npc-rowan-lantern.png')
        print('NPC_ANIMATION_COMPLETE',name,'seconds',round(time.time()-start,1),flush=True)
    m.BASE=PLAYER_BASE.copy()
    (T/'model/npc-motion-meta.json').write_text(json.dumps(metadata,indent=2))

if __name__=='__main__':
    player_tools();npcs()
