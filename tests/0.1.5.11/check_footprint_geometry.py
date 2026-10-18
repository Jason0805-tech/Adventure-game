from pathlib import Path
import json,math
ROOT=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
d=json.loads((ROOT/'output/adventure game 0.1.5.11/collision_profiles.json').read_text())
checks=0;fail=[]
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def intersect(a,b,c,e):
 return cross(a,b,c)*cross(a,b,e)<-1e-14 and cross(c,e,a)*cross(c,e,b)<-1e-14
for key,v in d.items():
 for which in ['polygons','visual_polygons']:
  for j,p in enumerate(v[which]):
   checks+=1
   if len(p)<3:fail.append([key,which,j,'fewerthan3'])
   a=abs(sum(p[i][0]*p[(i+1)%len(p)][1]-p[(i+1)%len(p)][0]*p[i][1] for i in range(len(p)))/2)
   if a<1e-7:fail.append([key,which,j,'zeroarea'])
   lo,hi=(0,1) if which=='polygons' else (-.1,1.1) # Legacy visual mask may extend just outside trimmed source; renderer clips it.
   if any(not(lo<=x<=hi and lo<=y<=hi and math.isfinite(x) and math.isfinite(y)) for x,y in p):fail.append([key,which,j,'range'])
   for i in range(len(p)):
    for q in range(i+2,len(p)):
     if i==0 and q==len(p)-1:continue
     if intersect(p[i],p[(i+1)%len(p)],p[q],p[(q+1)%len(p)]):fail.append([key,which,j,'selfintersect',i,q])
for key,v in d.items():
 checks+=1
 if not (0<=v['overhead_split_v']<=1):fail.append([key,'overhead_split_range'])
 if key.startswith('pond_') and not key.endswith('_rocks') and v['overhead_split_v']!=0:fail.append([key,'water_never_overhead'])
for key in ['pond_0_rocks','pond_1_rocks','pond_2_rocks']:
 checks+=1
 if len(d[key]['polygons'])!=len(d[key]['visual_polygons']):fail.append([key,'unpairedstones'])
 if len(d[key]['polygons'])!=len(d[key]['overhead_split_vs']):fail.append([key,'unpairedstonesplits'])
r={'polygon_geometry_checks':checks,'failures':fail,'all_ground_and_visual_polygons_simple':not fail}
(ROOT/'tests/0.1.5.11/footprint-authoring/geometry-results.json').write_text(json.dumps(r,indent=2)+'\n')
print(json.dumps(r,indent=2))
if fail:raise SystemExit(1)
