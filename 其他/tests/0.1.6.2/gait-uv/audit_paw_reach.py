"""Read-only native-alpha sole audit and per-leg reach recommendations.
No source RGBA, masks, animation runtime or physical contour is modified.
"""
from pathlib import Path
import json,math,re
import numpy as np
from PIL import Image
FOLDER=Path(__file__).resolve().parent
ROOT=FOLDER.parents[2]
RUNTIME=ROOT/'output/adventure game 0.1.6.2'
if not RUNTIME.exists():RUNTIME=ROOT/'output/adventure game 0.1.6.1'
meta=json.loads((RUNTIME/'assets/animal_atlas.json').read_text())['species']
text=(RUNTIME/'wildlife_data.gd').read_text()

def pip(points,polygon):
    polygon=np.asarray(polygon,float);x,y=points[:,0],points[:,1];inside=np.zeros(len(points),bool)
    for i,j in zip(range(len(polygon)),range(-1,len(polygon)-1)):
        xi,yi=polygon[i];xj,yj=polygon[j]
        inside^=((yi>y)!=(yj>y))&(x<(xj-xi)*(y-yi)/(yj-yi+1e-12)+xi)
    return inside

def smooth(a,b,t):
    u=np.clip((t-a)/(b-a),0,1)
    return u*u*(3-2*u)

def posed(part,phase,reach):
    root=np.array(part['root'],float);knee=np.array(part['knee'],float);ankle=np.array(part['ankle'],float)
    t=(phase+part['phase'])%1
    x=reach-4*reach*t if t<.5 else -reach*math.cos(math.pi*(t-.5)*2)
    lift=0 if t<.5 else part['lift']*math.sin(math.pi*(t-.5)*2)
    target=ankle+np.array(part.get("rest_shift",[0,0]))+np.array(part['forward'])*x+[0,-lift]
    upper=np.linalg.norm(knee-root);lower=np.linalg.norm(ankle-knee)
    axis=target-root;distance=np.clip(np.linalg.norm(axis),abs(upper-lower)+.001,upper+lower-.001)
    axis/=max(1e-12,np.linalg.norm(axis))
    along=(upper*upper-lower*lower+distance*distance)/(2*distance)
    height=math.sqrt(max(0,upper*upper-along*along))
    sign=np.sign((ankle-root)[0]*(knee-root)[1]-(ankle-root)[1]*(knee-root)[0])
    tk=root+axis*along+np.array([-axis[1],axis[0]])*height*sign
    ta=root+axis*distance
    ua=math.atan2(*(tk-root)[::-1])-math.atan2(*(knee-root)[::-1])
    la=math.atan2(*(ta-tk)[::-1])-math.atan2(*(ankle-knee)[::-1])
    return root,knee,ankle,tk,ta,ua,la

def transform(points,part,phase,reach):
    root,knee,ankle,tk,ta,ua,la=posed(part,phase,reach)
    def rot(values,angle):
        c,s=math.cos(angle),math.sin(angle)
        return values@np.array([[c,s],[-s,c]])
    axis=ankle-root;t=((points-root)@axis)/(axis@axis)
    upper=root+rot(points-root,ua)
    lower=tk+rot(points-knee,la)
    paw=points+ta-ankle
    result=upper+(lower-upper)*smooth(.32,.68,t)[:,None]
    result+=(paw-result)*smooth(.76,.91,t)[:,None]
    return points+(result-points)*smooth(.16,.64,t)[:,None]

def excess(points,g):
    ox,oy,rx,ry=g
    closest=np.stack([np.clip(points[:,0]-ox,-(rx-ry),rx-ry)+ox,np.full(len(points),oy)],axis=1)
    return np.maximum(0,np.linalg.norm(points-closest,axis=1)-ry)


def support_motion(points,part,reach,bias):
    root=np.asarray(part['root'],float);knee=np.asarray(part['knee'],float);ankle=np.asarray(part['ankle'],float)
    phases=(np.arange(49)/48+float(part['phase']))%1
    phases=phases[phases<=.50000001]
    xs=reach-4*reach*phases
    targets=ankle+np.asarray(bias)+xs[:,None]*np.asarray(part['forward'])
    upper_length=np.linalg.norm(knee-root);lower_length=np.linalg.norm(ankle-knee)
    axes=targets-root;dist=np.linalg.norm(axes,axis=1);axes/=np.maximum(dist[:,None],1e-12)
    dist=np.clip(dist,abs(upper_length-lower_length)+.001,upper_length+lower_length-.001)
    along=(upper_length**2-lower_length**2+dist**2)/(2*dist)
    height=np.sqrt(np.maximum(0,upper_length**2-along**2))
    v1=ankle-root;v2=knee-root;side=np.sign(v1[0]*v2[1]-v1[1]*v2[0])
    tk=root+axes*along[:,None]+np.stack([-axes[:,1],axes[:,0]],axis=1)*height[:,None]*side
    ta=root+axes*dist[:,None]
    ua=np.arctan2((tk-root)[:,1],(tk-root)[:,0])-math.atan2(*(knee-root)[::-1])
    la=np.arctan2((ta-tk)[:,1],(ta-tk)[:,0])-math.atan2(*(ankle-knee)[::-1])
    def rotate(v,a):
        c,s=np.cos(a)[:,None],np.sin(a)[:,None]
        return np.stack([c*v[:,0]-s*v[:,1],s*v[:,0]+c*v[:,1]],axis=2)
    axis=ankle-root;t=((points-root)@axis)/(axis@axis)
    upper=root+rotate(points-root,ua)
    lower=tk[:,None,:]+rotate(points-knee,la)
    paw=points[None,:,:]+ta[:,None,:]-ankle
    result=upper+(lower-upper)*smooth(.32,.68,t)[None,:,None]
    result+=(paw-result)*smooth(.76,.91,t)[None,:,None]
    return points[None,:,:]+(result-points[None,:,:])*smooth(.16,.64,t)[None,:,None]

y,x=np.mgrid[:384,:384]
centers=np.stack([x.ravel()+.5,y.ravel()+.5],axis=1)

report={};recommendations={};total_samples=0
for file in sorted(FOLDER.glob('source-legs-*.json')):
    if file.name not in {f'source-legs-{name}.json' for name in ['rabbit','deer','fox','wolf','bear']}:continue
    data=json.loads(file.read_text())
    for species,rows in data['species'].items():
        image=np.asarray(Image.open(RUNTIME/'assets'/f'wildlife-{species}.png').convert('RGBA'))
        block=text.split('"'+species+'":',1)[1].split('"habitats"',1)[0]
        ground=[tuple(map(float,s.split(',')))for s in re.findall(r'Vector4\(([^)]+)\)',block.split('"ground":[',1)[1].split(']',1)[0])]
        scale=meta[species]['world_height']/meta[species]['reference_height_px']
        output={};proposals={}
        for key,row in rows.items():
            direction=int(row['direction']);cell=image[:384,direction*384:(direction+1)*384]
            painted=cell[:,:,3].ravel()>25
            owned=np.zeros(len(centers),bool);parts=[]
            for part in row['legs']:
                own=pip(centers,part['mask'])&~owned
                owned|=pip(centers,part['mask'])
                pixels=(painted&own&pip(centers,part['paw_mask'])).reshape(384,384)
                points=[]
                for column in np.where(pixels.any(axis=0))[0]:
                    row_y=np.where(pixels[:,column])[0][-1]
                    points.append([column+.5,row_y+.5])
                points=np.array(points,float).reshape(-1,2)
                if not len(points):
                    parts.append({'name':part['name'],'error':'No owned visible alpha in paw mask'});continue
                all_base=excess((points-[192,320])*scale,ground[direction])
                contact=all_base<=.5
                excluded=int((~contact).sum())
                points=points[contact]
                if not len(points):
                    parts.append({'name':part['name'],'source_sole_points':int(len(all_base)),'excluded_preexisting_raised_or_fur':excluded,'baseline_max_excess_world':float(all_base.max()),'note':'No original ground-contact sole samples; not clamped as a ground foot.'})
                    continue
                base=all_base[contact]
                def check_reach(reach,bias=(0,0)):
                    warped=support_motion(points,part,reach,bias)
                    current=excess(((warped-[192,320])*scale).reshape(-1,2),ground[direction]).reshape(warped.shape[:2])
                    return max(0.,float((current-base).max())),float(current.max())
                requested=float(part['reach']);original_bias=np.asarray(part.get('rest_shift',[0,0]),float)
                growth,strict=check_reach(requested,original_bias)
                best_bias=original_bias.copy();best_growth=growth
                limit=max(5.,requested*1.1)
                def cost(bias):
                    g,_=check_reach(requested,bias)
                    return max(0,g-.20)*1000+np.linalg.norm(bias-original_bias)*.01,g
                best_cost,_=cost(best_bias)
                if best_growth>.25:
                    for step in [4.,2.,1.,.5,.25]:
                        for _ in range(6):
                            changed=False
                            for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                                candidate=best_bias+np.array([dx,dy])*step
                                if np.linalg.norm(candidate-original_bias)>limit:continue
                                c,g=cost(candidate)
                                if c<best_cost-1e-8:
                                    best_cost=c;best_growth=g;best_bias=candidate;changed=True
                            if not changed:break
                lo,hi=0.,requested
                if check_reach(requested,best_bias)[0]>.25:
                    for _ in range(10):
                        mid=(lo+hi)/2
                        if check_reach(mid,best_bias)[0]<=.25:lo=mid
                        else:hi=mid
                    safe=math.floor(lo*100)/100
                else:safe=requested
                total_samples+=len(points)
                parts.append({'name':part['name'],'source_sole_points':int(len(all_base)),'contact_sole_points':len(points),'excluded_preexisting_raised_or_fur':excluded,'baseline_max_excess_world':float(all_base.max()),'contact_baseline_max_excess_world':float(base.max()),'requested_reach_native':requested,'requested_max_extra_excess_world':growth,'requested_max_excess_world':strict,'recommended_rest_shift_native':best_bias.tolist(),'shifted_max_extra_excess_world':check_reach(requested,best_bias)[0],'recommended_reach_native':safe})

            output[key]=parts;proposals[key]=proposals.copy() if False else {p['name']:p.get('recommended_reach_native') for p in parts}
        report[species]=output;recommendations[species]={key:{p['name']:p.get('recommended_reach_native') for p in parts}for key,parts in output.items()}
(FOLDER/'independent-paw-reach-audit.json').write_text(json.dumps({'alpha_threshold':.1,'original_ground_contact_tolerance_world':.5,'allowed_additional_excess_world':.25,'sole_samples':total_samples,'species':report},indent=2)+'\n')
(FOLDER/'recommended-reach-clamps.json').write_text(json.dumps(recommendations,indent=2)+'\n')
for name,rows in report.items():
    parts=[p for row in rows.values() for p in row]
    clamps=[(k,p['name'],p['requested_reach_native'],p['recommended_reach_native'],round(p['requested_max_excess_world'],3))for k,row in rows.items() for p in row if 'recommended_reach_native'in p and p['recommended_reach_native']<p['requested_reach_native']]
    print(name,'legs',len(parts),'clamps_after_registration',clamps,'registration_changes',[(k,p['name'],p['recommended_rest_shift_native'])for k,row in rows.items()for p in row if 'recommended_rest_shift_native'in p and p['recommended_rest_shift_native']!=[0.,0.]],'empty',[p['name']for p in parts if 'error'in p])
