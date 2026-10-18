from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'tests/0.1.5.7/profile-sprites'
PROFILE=ROOT/'output/adventure game 0.1.5.7/collision_profiles.json'
profiles=json.loads(PROFILE.read_text()) if PROFILE.exists() else {}
groups={
 'trees':['tree_'+str(i) for i in range(6)],
 'shrubs':['shrub_'+str(i) for i in range(4)],
 'camp':['cabin']+['prop_'+str(i) for i in range(6)]+['bench','gate'],
 'rock_and_stumps':['stump_'+str(i) for i in range(2)]+['ore_'+str(i) for i in range(3)],
 'resources':['resource_'+k+'_'+str(i) for k in ['branch','rock','rope'] for i in range(3)],
 'remnants':['resource_'+k+'_spent_'+str(i) for k in ['branch','rock','rope'] for i in range(3)],
 'ponds':['pond_'+str(i) for i in range(3)]}
for title,keys in groups.items():
 cols=3; cw=330; ch=380
 sheet=Image.new('RGB',(cols*cw,((len(keys)+cols-1)//cols)*ch),'#d8dec8');d=ImageDraw.Draw(sheet)
 for i,key in enumerate(keys):
  x=(i%cols)*cw+25;y=(i//cols)*ch+30
  im=Image.open(BASE/(key+'.png')).convert('RGBA')
  box=Image.new('RGBA',(280,280),(208,218,197,255));box.alpha_composite(im.resize((280,280)))
  sheet.paste(box.convert('RGB'),(x,y))
  for line in range(11):
   q=line*28; d.line((x+q,y,x+q,y+280),fill='#7d9283',width=1);d.line((x,y+q,x+280,y+q),fill='#7d9283',width=1)
  for poly in profiles.get(key,{}).get('polygons',[]):
   points=[(x+v[0]*280,y+v[1]*280) for v in poly]
   d.polygon(points,fill=None,outline='#f73a4e',width=3)
   for pt in points:d.ellipse((pt[0]-2,pt[1]-2,pt[0]+2,pt[1]+2),fill='#f73a4e')
  if key in profiles:
   q=y+profiles[key]['depth_v']*280;d.line((x,q,x+280,q),fill='#443cff',width=2)
  d.text((x,y-22),key,fill='#172b23')
  d.text((x,y+287),'UV: x/y grid step 0.1',fill='#172b23')
  d.text((x,y+304),str(im.size),fill='#172b23')
 sheet.save(BASE/(title+'-'+('verified' if profiles else 'uv')+'.png'))
