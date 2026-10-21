"""Geometry-only audit: columns quantify why one scalar base depth is insufficient.
No collider is changed and these are not claimed as walk-through test results.
"""
import json,pathlib,statistics
root=pathlib.Path(__file__).resolve().parents[3]
profiles=json.loads((root/'output/adventure game 0.1.5.9/collision_profiles.json').read_text())
meta=json.loads((root/'tests/0.1.5.8/density-renders/density-metadata.json').read_text())['objects']

def intersections(poly,x):
 ys=[]
 for i,(ax,ay) in enumerate(poly):
  bx,by=poly[(i+1)%len(poly)]
  if min(ax,bx)<=x<=max(ax,bx) and abs(ax-bx)>1e-9:
   ys.append(ay+(by-ay)*(x-ax)/(bx-ax))
 return ys
out=[]
for key,v in profiles.items():
 if key.startswith('pond_') and key.endswith('_rocks'):
  source='pond_'+key[5]
 else:source=key
 if source not in meta:continue
 h=meta[source]['world'][1]
 samples=[]
 for i in range(1,1000):
  x=i/1000
  ys=[y for poly in v['polygons'] for y in intersections(poly,x)]
  if ys:samples.append({'u':x,'local_bottom_v':max(ys),'global_minus_local_world':(v['depth_v']-max(ys))*h})
 if not samples:continue
 q=[s['global_minus_local_world'] for s in samples]
 representative=sorted(samples,key=lambda s:abs(s['u']-.40))[0]
 out.append({'profile':key,'world_height':h,'global_depth_v':v['depth_v'],'max_false_behind_band_world':round(max(q),3),'median_false_behind_band_world':round(statistics.median(q),3),'near_u_040':representative,'columns_sampled':len(samples)})
(root/'tests/0.1.5.9/occlusion-audit/profile-depth-variation.json').write_text(json.dumps({'note':'These measure local lower collider boundaries against scalar object depth. Some points are intentionally passable foliage/arch, not all are observed failures. No runtime changes.','profiles':out},indent=2))
for row in out:
 if row['profile'] in ['cabin','prop_1','bench','shrub_0','ore_0','stump_0','gate','tree_5']:
  print(row['profile'],'max=',row['max_false_behind_band_world'],'median=',row['median_false_behind_band_world'],'at_u_0.4=',round(row['near_u_040']['global_minus_local_world'],2))
