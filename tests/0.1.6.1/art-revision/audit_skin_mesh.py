"""Independent read-only source-pixel/triangle audit of exported native UV skinning."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
FOLDER=Path(__file__).resolve().parent
geometry=json.loads((FOLDER/'uv-proof-geometry.json').read_text())
output={}
for species,record in geometry.items():
    source=np.asarray(record['source_points'],dtype=float)
    idle=np.asarray(record['idle_points'],dtype=float)
    tri=np.asarray(record['indices'],dtype=int).reshape(-1,3)
    atlas=np.asarray(Image.open(ROOT/'output/adventure game 0.1.6.1/assets'/f'wildlife-{species}.png').convert('RGBA'))
    direction=int(record['definition']['direction'])
    cell=atlas[:384,direction*384:(direction+1)*384]
    st=source[tri]
    basis=np.stack([st[:,1]-st[:,0],st[:,2]-st[:,0]],axis=-1)
    source_determinant=np.linalg.det(basis)
    degenerate=int((np.abs(source_determinant)<1e-7).sum())
    keep=np.abs(source_determinant)>=1e-7
    tri=tri[keep];st=st[keep];basis=basis[keep]
    inv=np.linalg.inv(basis)
    lower=st.min(axis=1).astype(int)
    # Exact native pixel centers belonging to each source triangle, including
    # partially transparent fur. This avoids classifying transparent gaps as fur.
    visible=np.zeros(len(tri),bool)
    for dy in range(4):
        for dx in range(4):
            p=lower+np.array([dx+.5,dy+.5])
            bary=np.einsum('nij,nj->ni',inv,p-st[:,0])
            inside=(bary[:,0]>=-1e-8)&(bary[:,1]>=-1e-8)&(bary.sum(axis=1)<=1+1e-8)
            x=np.clip(lower[:,0]+dx,0,383);y=np.clip(lower[:,1]+dy,0,383)
            visible|=inside&(cell[y,x,3]>25)
    source_det=np.linalg.det(basis)
    frames=[]
    for phase,frame in enumerate(record['frames']):
        dest=np.asarray(frame,dtype=float)[tri]
        db=np.stack([dest[:,1]-dest[:,0],dest[:,2]-dest[:,0]],axis=-1)
        deformation=db@inv
        ratio=np.linalg.det(db)/source_det
        singular=np.linalg.svd(deformation[visible],compute_uv=False)
        bad=np.where(visible&(ratio<0))[0]
        frames.append({'phase':phase/len(record['frames']), 'flipped_visible':int(len(bad)),
                       'visible_min_area_ratio':float(ratio[visible].min()),
                       'visible_max_area_ratio':float(ratio[visible].max()),
                       'visible_max_linear_stretch':float(singular[:,0].max()),
                       'visible_p95_linear_stretch':float(np.percentile(singular[:,0],95)),
                       'example_source_triangles':st[bad[:3]].tolist()})
    output[species]={'idle_exact':bool(np.array_equal(source,idle)),
                     'idle_max_position_delta':float(np.linalg.norm(source-idle,axis=1).max()),
                     'visible_source_triangles':int(visible.sum()),'total_triangles':len(tri),'degenerate_source_triangles':degenerate,
                     'total_flipped_visible':sum(f['flipped_visible'] for f in frames),
                     'max_linear_stretch':max(f['visible_max_linear_stretch'] for f in frames),
                     'frames':frames}
(FOLDER/'independent-mesh-audit.json').write_text(json.dumps(output,indent=2)+'\n')
for name,result in output.items():
    print(name, {k:v for k,v in result.items() if k!='frames'})
