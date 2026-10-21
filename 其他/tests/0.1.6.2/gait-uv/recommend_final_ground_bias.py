"""Recommend moving-only registration for the production affine native-paw field.
Uses actual current metadata and unchanged ground capsules; changes no runtime file.
"""
from pathlib import Path
import json,re,math,sys
import numpy as np
from PIL import Image
FOLDER=Path(__file__).resolve().parent;ROOT=FOLDER.parents[2];RELEASE=ROOT/'output/adventure game 0.1.6.2'
VERIFY_ONLY='--verify-only' in sys.argv
metadata=json.loads((RELEASE/'assets/animal_atlas.json').read_text())['species']
physics=(RELEASE/'wildlife_data.gd').read_text()
y,x=np.mgrid[:384,:384];pixels=np.stack([x.ravel()+.5,y.ravel()+.5],axis=-1)
def inside(points,polygon):
    v=np.asarray(polygon,float);px,py=points[:,0],points[:,1];mask=np.zeros(len(points),bool)
    for i,j in zip(range(len(v)),range(-1,len(v)-1)):
        xi,yi=v[i];xj,yj=v[j];mask^=((yi>py)!=(yj>py))&(px<(xj-xi)*(py-yi)/(yj-yi+1e-12)+xi)
    return mask

def smooth(a,b,t):
    u=np.clip((t-a)/(b-a),0,1);return u*u*(3-2*u)
def excess(p,g):
    ox,oy,rx,ry=g;n=np.stack([np.clip(p[...,0]-ox,-(rx-ry),rx-ry)+ox,np.full(p.shape[:-1],oy)],axis=-1)
    return np.maximum(0,np.linalg.norm(p-n,axis=-1)-ry)
report={};patches={};changed=0
for species,m in metadata.items():
    atlas=np.asarray(Image.open(RELEASE/'assets'/f'wildlife-{species}.png').convert('RGBA'))
    block=physics.split('"'+species+'":',1)[1].split('"habitats"',1)[0]
    gs=[tuple(map(float,s.split(',')))for s in re.findall(r'Vector4\(([^)]+)\)',block.split('"ground":[',1)[1].split(']',1)[0])]
    scale=m['world_height']/m['reference_height_px'];rows={};updates={}
    for direction in range(8):
        d=m['source_skin'][str(direction)];image=atlas[:384,direction*384:(direction+1)*384];owned=np.zeros(len(pixels),bool);parts=[];mods={}
        for leg in d['legs']:
            mask=inside(pixels,leg['mask']);own=mask&~owned;owned|=mask
            visible=(own&inside(pixels,leg['paw_mask'])&(image[:,:,3].ravel()>25)).reshape(384,384)
            sole=np.asarray([[col+.5,np.where(visible[:,col])[0][-1]+.5]for col in np.where(visible.any(axis=0))[0]],float).reshape(-1,2)
            if not len(sole):continue
            baseline=excess((sole-[192,320])*scale,gs[direction]);keep=baseline<=.5;sole=sole[keep];baseline=baseline[keep]
            if not len(sole):continue
            root=np.asarray(leg['root'],float);ankle=np.asarray(leg['ankle'],float);forward=np.asarray(leg['forward'],float);reach=float(leg['reach'])
            top=min([ankle[1]]+[p[1]for p in leg['paw_mask']]);start=root[1]+max(0,(ankle[1]-root[1])*.04);end=max(start+8,top)
            lower=np.floor(sole[:,1]/4)*4;w=smooth(start,end,lower)+(smooth(start,end,lower+4)-smooth(start,end,lower))*((sole[:,1]-lower)/4)
            original=np.asarray(leg.get('rest_shift',[0,0]),float)
            def measure(bias):
                xs=[-reach,reach]
                if abs(forward[1])>1e-9:
                    hinge=(-.5*(end-start)-bias[1])/forward[1]
                    if -reach<hinge<reach:xs.append(hinge)
                delta=np.asarray(bias)[None,:]+np.asarray(xs)[:,None]*forward
                delta[:,1]=np.maximum(delta[:,1],-.5*(end-start))
                warped=sole[None,:,:]+delta[:,None,:]*w[None,:,None]
                now=excess((warped-[192,320])*scale,gs[direction])
                return max(0.,float((now-baseline).max())),float(now.max())
            initial,strict=measure(original);best=original.copy()
            def cost(bias):
                growth,_=measure(bias)
                return max(0,growth-.18)*10000+float(np.linalg.norm(bias-original))*.001
            c=cost(best)
            if initial>.2 and not VERIFY_ONLY:
                for step in [4.,2.,1.,.5,.25,.125,.0625]:
                    for _ in range(8):
                        progress=False
                        for dx,dy in [(-1,0),(1,0),(0,-1),(0,1),(-1,-1),(-1,1),(1,-1),(1,1)]:
                            trial=best+np.array([dx,dy])*step
                            if np.linalg.norm(trial-original)>max(20.,reach*2):continue
                            tc=cost(trial)
                            if tc<c-1e-9:c=tc;best=trial;progress=True
                        if not progress:break
            final,final_strict=measure(best)
            note={'name':leg['name'],'reach_unchanged':reach,'original_rest_shift':original.tolist(),'proposed_rest_shift':best.tolist(),'initial_extra_excess':initial,'final_extra_excess':final,'final_total_excess':final_strict,'source_contact_points':len(sole)}
            parts.append(note)
            if not np.array_equal(best,original):mods[leg['name']]={'rest_shift':best.tolist(),'reach':reach};changed+=1
        rows[str(direction)]=parts
        if mods:updates[str(direction)]=mods
    report[species]=rows
    if updates:patches[species]=updates
if VERIFY_ONLY:
    (FOLDER/'final-ground-bias-verification.json').write_text(json.dumps(report,indent=2)+'\n')
else:
    (FOLDER/'final-ground-bias-audit.json').write_text(json.dumps(report,indent=2)+'\n')
    (FOLDER/'final-ground-bias-patch.json').write_text(json.dumps(patches,indent=2)+'\n')
for species,rows in report.items():
    changes=[(k,p['name'],p['original_rest_shift'],p['proposed_rest_shift'],round(p['initial_extra_excess'],3),round(p['final_extra_excess'],3))for k,parts in rows.items()for p in parts if p['original_rest_shift']!=p['proposed_rest_shift']]
    print(species,changes)
if VERIFY_ONLY:
    values=[p['initial_extra_excess']for rows in report.values()for parts in rows.values()for p in parts]
    print('FINAL_CONTINUOUS_SUPPORT_VERIFICATION contact_paws=',len(values),'max_additional_excess_world=',max(values,default=0),'failures=',sum(v>.35 for v in values),'source RGBA/physics untouched')
    raise SystemExit(1 if any(v>.35 for v in values)else 0)
else:
    print('FINAL_GROUND_BIAS_RECOMMENDATIONS',changed,'keeping every source paw and requested reach; no runtime edits')
