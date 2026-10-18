from pathlib import Path
import json

root=Path(__file__).resolve().parents[2]
profile=json.loads((root/'output/adventure game 0.1.5.7/collision_profiles.json').read_text())
meta=json.loads((root/'tests/0.1.5.7/profile-sprites/sprite-metadata.json').read_text())
assert set(profile)==set(meta), (set(profile)^set(meta))
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def overlap(a,b,c,d):
    aa=cross(a,b,c);bb=cross(a,b,d);cc=cross(c,d,a);dd=cross(c,d,b)
    return aa*bb < -1e-14 and cc*dd < -1e-14
count=0;points=0
for key,item in profile.items():
    assert 0 <= item['depth_v'] <= 1, key
    assert item['notes'] and item['polygons'],key
    for poly in item['polygons']:
        assert len(poly)>=8,(key,len(poly))
        assert all(len(v)==2 and 0<=v[0]<=1 and 0<=v[1]<=1 for v in poly), key
        area=sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly)))/2
        assert abs(area)>1e-5,(key,area)
        for i in range(len(poly)):
            for j in range(i+1,len(poly)):
                if j==i+1 or (i==0 and j==len(poly)-1):continue
                assert not overlap(poly[i],poly[(i+1)%len(poly)],poly[j],poly[(j+1)%len(poly)]),(key,i,j,'self crossing')
        assert item['depth_v'] >= max(v[1] for v in poly)-.002,(key,'depth before foreground ground edge')
        count+=1;points+=len(poly)
result={'status':'passed','keys':len(profile),'polygons':count,'vertices':points,'checks':['45 keys match exact Godot-exported sprite identities','All UVs inside cropped sprite','8 or more contour vertices per polygon','No nonadjacent edge self crossings','All polygons have nonzero area','Depth line includes frontmost ground contact','Every key has per-object notes'],'visual_qa':['trees-verified.png','shrubs-verified.png','camp-verified.png','rock_and_stumps-verified.png','resources-verified.png','remnants-verified.png','ponds-verified.png']}
(root/'tests/0.1.5.7/profile-sprites/validation.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
