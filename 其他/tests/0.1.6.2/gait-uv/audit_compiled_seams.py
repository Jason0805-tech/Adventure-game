"""Find opaque source cut edges that separate after native UV skinning."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
FOLDER=Path(__file__).resolve().parent
ROOT=FOLDER.parents[2]
report={}
for file in sorted((FOLDER/'independent_geometry').glob('*.json')):
    data=json.loads(file.read_text());species=data['species'];direction=data['direction']
    atlas=np.asarray(Image.open(ROOT/'output/adventure game 0.1.6.2/assets'/f'wildlife-{species}.png').convert('RGBA'))
    image=atlas[:384,direction*384:(direction+1)*384]
    edges={};parts={}
    for part in data['parts']:
        owner=int(part['owner']);source=np.asarray(part['source'],float);tri=np.asarray(part['indices'],int).reshape(-1,3)
        frames=np.asarray(part['frames'],float)if owner>=0 else np.broadcast_to(source,(25,*source.shape))
        parts[owner]=(source,frames)
        local={}
        for t in tri:
            for a,b in [(t[0],t[1]),(t[1],t[2]),(t[2],t[0])]:
                av=tuple(np.round(source[a],4));bv=tuple(np.round(source[b],4))
                if av==bv:continue
                if av>bv:av,bv=bv,av;a,b=b,a
                key=(av,bv)
                if key not in local:local[key]=[0,a,b,source[t].mean(axis=0)]
                local[key][0]+=1
        for key,(count,a,b,inside)in local.items():
            if count==1:edges.setdefault(key,[]).append((owner,a,b,inside))
    result=[]
    for key,records in edges.items():
        if len(records)!=2 or records[0][0]==records[1][0]:continue
        (oa,ia,ja,inside),(ob,ib,jb,_)=records
        a,b=np.asarray(key,float);mid=(a+b)/2
        px,py=np.floor(mid).astype(int)
        if not(0<=px<384 and 0<=py<384)or image[py,px,3]<230:continue
        edge=b-a;length=np.linalg.norm(edge)
        if length<.1:continue
        cross=edge[0]*(inside-mid)[1]-edge[1]*(inside-mid)[0]
        normal=np.array([-edge[1],edge[0]])/length*(-1 if cross>0 else 1)
        da=(parts[oa][1][:,ia]+parts[oa][1][:,ja])/2
        db=(parts[ob][1][:,ib]+parts[ob][1][:,jb])/2
        gaps=(db-da)@normal
        maximum=float(gaps.max())
        if maximum>.25:
            result.append({'source_edge':[a.tolist(),b.tolist()],'owners':[oa,ob],'source_alpha':int(image[py,px,3]),'max_gap_native':maximum,'phase':float(gaps.argmax()/24),'phase04_gap_native':float(gaps[4]),'length_native':float(length)})
    result.sort(key=lambda r:r['max_gap_native'],reverse=True)
    report[f'{species}:{direction}']={'opaque_separated_edges':len(result),'max_gap_native':result[0]['max_gap_native']if result else 0,'examples':result[:20]}
(FOLDER/'independent-visible-seams.json').write_text(json.dumps(report,indent=2)+'\n')
for key in ['fox:2','bear:2','deer:0','deer:1']:
    print(key,report.get(key))
