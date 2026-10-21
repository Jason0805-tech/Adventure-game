"""Independent source-alpha, UV partition, visible deformation and sole audit.
Input is exported from the *compiled production* topology, without reauthoring it.
"""
from pathlib import Path
import json,re,hashlib
import numpy as np
from PIL import Image
FOLDER=Path(__file__).resolve().parent
ROOT=FOLDER.parents[2]
RELEASE=ROOT/'output/adventure game 0.1.6.2'
meta=json.loads((RELEASE/'assets/animal_atlas.json').read_text())['species']
physics=(RELEASE/'wildlife_data.gd').read_text()

def pip(points,polygon):
    v=np.asarray(polygon,float);x,y=points[:,0],points[:,1];inside=np.zeros(len(points),bool)
    for i,j in zip(range(len(v)),range(-1,len(v)-1)):
        xi,yi=v[i];xj,yj=v[j]
        inside^=((yi>y)!=(yj>y))&(x<(xj-xi)*(y-yi)/(yj-yi+1e-12)+xi)
    return inside

def excess(points,g):
    ox,oy,rx,ry=g
    nearest=np.stack([np.clip(points[...,0]-ox,-(rx-ry),rx-ry)+ox,np.full(points.shape[:-1],oy)],axis=-1)
    return np.maximum(0,np.linalg.norm(points-nearest,axis=-1)-ry)

y,x=np.mgrid[:384,:384];pixel_centers=np.stack([x.ravel()+.5,y.ravel()+.5],axis=-1)
report={'headings':{},'hashes':{},'production_artifacts':{},'failures':[]}
for name in ['animal_gait.gd','assets/animal_atlas.json','assets/animal-skin-topology.bin']:
    p=RELEASE/name
    report['production_artifacts'][name]={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size_bytes':p.stat().st_size}
for name in ['wildlife.gd','wildlife_data.gd','npc_roaming.gd','world_geometry.gd','collision_profiles.json','inventory.gd','item_data.gd','world_lighting.gd']:
    a=ROOT/'output/adventure game 0.1.6.1'/name;b=RELEASE/name
    same=a.read_bytes()==b.read_bytes()
    report['hashes'][name]={'unchanged_from_0161':same,'sha256':hashlib.sha256(b.read_bytes()).hexdigest()}
    if not same:report['failures'].append('Non-art module changed: '+name)
for species in meta:
    p=RELEASE/'assets'/f'wildlife-{species}.png'
    original=ROOT/'output/adventure game 0.1.6/assets'/p.name
    same=p.read_bytes()==original.read_bytes()
    report['hashes'][p.name]={'unchanged_from_016':same,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    if not same:report['failures'].append('Native source changed: '+species)

for file in sorted((FOLDER/'independent_geometry').glob('*.json')):
    data=json.loads(file.read_text());species=data['species'];direction=int(data['direction']);definition=data['definition']
    if definition!=meta[species]['source_skin'][str(direction)]:
        report['failures'].append(f'{species}:{direction} exported geometry uses stale production metadata')
    scale=float(data['scale']);anchor=np.array(data['anchor'],float)
    atlas=np.asarray(Image.open(RELEASE/'assets'/f'wildlife-{species}.png').convert('RGBA'))
    image=atlas[:384,direction*384:(direction+1)*384];alpha=image[:,:,3]>25
    block=physics.split('"'+species+'":',1)[1].split('"habitats"',1)[0]
    grounds=[tuple(map(float,v.split(',')))for v in re.findall(r'Vector4\(([^)]+)\)',block.split('"ground":[',1)[1].split(']',1)[0])]
    ground=grounds[direction]
    covered=np.zeros((384,384),np.uint16);strict_cover=np.zeros_like(covered)
    record={'source_area':0.,'painted_source_pixels':int(alpha.sum()),'uv_max_error':0.,'visible_flips':0,'visible_collapses':0,'visible_triangle_phase_checks':0,'max_visible_linear_stretch':1.,'parts':[],'soles':[]}
    part_cache={}
    for part in data['parts']:
        owner=int(part['owner']);source=np.asarray(part['source'],float);uvs=np.asarray(part['uvs'],float);tri=np.asarray(part['indices'],int).reshape(-1,3)
        expected=(source+[direction*384,0])/np.array([3072,1536])
        record['uv_max_error']=max(record['uv_max_error'],float(np.abs(expected-uvs).max(initial=0)))
        st=source[tri];basis=np.stack([st[:,1]-st[:,0],st[:,2]-st[:,0]],axis=-1)
        determinants=np.linalg.det(basis);valid=np.abs(determinants)>1e-7
        if not valid.all():
            tri=tri[valid];st=st[valid];basis=basis[valid];determinants=determinants[valid]
        inverse=np.linalg.inv(basis)
        record['source_area']+=float(np.abs(determinants).sum()/2)
        visible=np.zeros(len(tri),bool)
        for i,t in enumerate(st):
            lo=np.maximum(0,np.floor(t.min(axis=0)).astype(int));hi=np.minimum(384,np.ceil(t.max(axis=0)).astype(int))
            yy,xx=np.mgrid[lo[1]:hi[1],lo[0]:hi[0]]
            if not xx.size:continue
            points=np.stack([xx+.5,yy+.5],axis=-1)
            bary=(points-t[0])@inverse[i].T
            inclusive=(bary[...,0]>=-1e-7)&(bary[...,1]>=-1e-7)&(bary.sum(axis=-1)<=1+1e-7)
            strict=(bary[...,0]>1e-7)&(bary[...,1]>1e-7)&(bary.sum(axis=-1)<1-1e-7)
            covered[yy,xx]+=inclusive;strict_cover[yy,xx]+=strict
            visible[i]=bool((inclusive&alpha[yy,xx]).any())
        part_record={'owner':owner,'triangles':len(tri),'visible_triangles':int(visible.sum()),'visible_flips':0,'min_visible_area_ratio':1.,'max_visible_linear_stretch':1.,'examples':[]}
        frames=np.asarray(part['frames'],float) if owner>=0 else np.array([source])
        for frame,points in enumerate(frames):
            if owner<0:break
            record['visible_triangle_phase_checks']+=int(visible.sum())
            dt=points[tri];db=np.stack([dt[:,1]-dt[:,0],dt[:,2]-dt[:,0]],axis=-1)
            ratio=np.linalg.det(db)/determinants
            bad=np.where(visible&(ratio<-.001))[0]
            part_record['visible_flips']+=len(bad)
            record['visible_collapses']+=int((visible&(np.abs(ratio)<=.001)).sum())
            if visible.any():
                jac=db[visible]@inverse[visible]
                stretch=np.linalg.svd(jac,compute_uv=False)[:,0]
                part_record['max_visible_linear_stretch']=max(part_record['max_visible_linear_stretch'],float(stretch.max()))
                part_record['min_visible_area_ratio']=min(part_record['min_visible_area_ratio'],float(ratio[visible].min()))
            if len(bad) and len(part_record['examples'])<3:
                part_record['examples'].append({'phase':frame/24,'source':st[bad[0]].tolist(),'area_ratio':float(ratio[bad[0]])})
        record['visible_flips']+=part_record['visible_flips']
        record['max_visible_linear_stretch']=max(record['max_visible_linear_stretch'],part_record['max_visible_linear_stretch'])
        record['parts'].append(part_record)
        part_cache[owner]=(source,tri,st,inverse,frames)
    record['painted_source_holes']=int(((covered==0)&alpha).sum())
    record['painted_source_interior_overlaps']=int(((strict_cover>1)&alpha).sum())
    record['source_coverage_min']=int(covered.min())
    record['source_area_error']=record['source_area']-384*384
    owned=np.zeros(len(pixel_centers),bool)
    assignment=np.full(len(pixel_centers),-1,int)
    for i,part in enumerate(definition['legs']):
        candidate=pip(pixel_centers,part['mask'])
        assignment[candidate&(assignment<0)]=i
    for owner,leg in enumerate(definition['legs']):
        mask=pip(pixel_centers,leg['mask']);part_owned=mask&~owned;owned|=mask
        raw_paw=pip(pixel_centers,leg['paw_mask'])&alpha.ravel()
        static_paw=raw_paw&(assignment<0)&(pixel_centers[:,1]>=float(leg['ankle'][1])-6.0)
        valid=(part_owned&raw_paw).reshape(384,384)
        sole=[]
        for col in np.where(valid.any(axis=0))[0]:sole.append([col+.5,np.where(valid[:,col])[0][-1]+.5])
        sole=np.asarray(sole,float).reshape(-1,2)
        if not len(sole) or owner not in part_cache:
            record['soles'].append({'owner':owner,'name':leg['name'],'source_sole_points':len(sole),'note':'No separate visible owned source paw.'});continue
        original=excess((sole-anchor)*scale,ground)
        eligible=original<=.5
        contact=sole[eligible];baseline=original[eligible]
        entry={'owner':owner,'name':leg['name'],'potential_static_paw_pixels':int(static_paw.sum()),'potential_static_paw_examples':pixel_centers[static_paw][:4].tolist(),'source_sole_points':len(sole),'contact_sole_points':len(contact),'excluded_preexisting_raised_or_fur':int((~eligible).sum()),'original_max_excess_world':float(original.max())}
        if not len(contact):
            entry['note']='Original source paw is raised/outside the ground projection; preserved in baseline, not counted as calf collision.'
            record['soles'].append(entry);continue
        source,tri,st,inverse,frames=part_cache[owner]
        delta=contact[:,None,:]-st[None,:,0,:]
        bary=np.einsum('tij,ptj->pti',inverse,delta)
        inside=(bary[...,0]>=-1e-5)&(bary[...,1]>=-1e-5)&(bary.sum(axis=-1)<=1+1e-5)
        missing=~inside.any(axis=1)
        entry['source_contact_uncovered']=int(missing.sum())
        which=inside.argmax(axis=1);weights=np.concatenate([1-bary.sum(axis=-1,keepdims=True),bary],axis=-1)[np.arange(len(contact)),which]
        positions=frames[:,tri[which],:]
        warped=np.einsum('fpij,pi->fpj',positions,weights)
        phases=(np.arange(len(frames))/24+float(leg['phase']))%1
        support=phases<=.5000001
        current=excess((warped[support]-anchor)*scale,ground)
        entry['support_samples']=int(current.size)
        entry['max_contact_excess_world']=float(current.max())
        entry['max_additional_contact_excess_world']=max(0.,float((current-baseline).max()))
        record['soles'].append(entry)
    key=f'{species}:{direction}'
    report['headings'][key]=record
    if record['uv_max_error']>1e-6:report['failures'].append(key+' incorrect source UV')
    if record['painted_source_holes']:report['failures'].append(key+' painted source hole')
    if record['painted_source_interior_overlaps']:report['failures'].append(key+' painted source overlap')
    # Tiny transparent-padding clipping differences are diagnostic only; actual
    # painted native pixels must have no holes or overlapping interiors above.
    if record['visible_flips']:report['failures'].append(key+' visible triangle inversion')
    for sole in record['soles']:
        if sole.get('source_contact_uncovered',0):report['failures'].append(key+'/'+sole['name']+' missing source contact')
        if sole.get('max_additional_contact_excess_world',0)>.35:report['failures'].append(key+'/'+sole['name']+' additional ground excess '+str(round(sole['max_additional_contact_excess_world'],3)))
report['summary']={
    'headings':len(report['headings']),
    'original_painted_pixels_covered':sum(r['painted_source_pixels']for r in report['headings'].values()),
    'visible_triangle_phase_checks':sum(r['visible_triangle_phase_checks']for r in report['headings'].values()),
    'actual_support_sole_samples':sum(s.get('support_samples',0)for r in report['headings'].values()for s in r['soles']),
    'unchanged_physics_behavior_and_source_files':len(report['hashes']),
    'max_additional_contact_excess_world':max((s.get('max_additional_contact_excess_world',0)for r in report['headings'].values()for s in r['soles']),default=0),
    'failures':len(report['failures'])}
(FOLDER/'independent-compiled-skin-audit.json').write_text(json.dumps(report,indent=2)+'\n')
for species in meta:
    rows=[r for key,r in report['headings'].items()if key.startswith(species+':')]
    print(species,{'headings':len(rows),'visible_flips':sum(r['visible_flips']for r in rows),'source_holes':sum(r['painted_source_holes']for r in rows),'source_overlaps':sum(r['painted_source_interior_overlaps']for r in rows),'max_additional_ground_excess':max((s.get('max_additional_contact_excess_world',0)for r in rows for s in r['soles']),default=0),'max_stretch':max((r['max_visible_linear_stretch']for r in rows),default=0)})
print('COMPILED_SKIN_AUDIT headings=',len(report['headings']),'failures=',len(report['failures']))
for line in report['failures'][:40]:print('FAIL',line)
raise SystemExit(1 if report['failures']or len(report['headings'])!=40 else 0)
