"""Separate physical ground footprints from elevated paint for 0.1.5.11.

The 45 individually drawn ground-plane profiles were visually audited against
runtime-trimmed source crops. Their base projection is retained rather than
tracing tall object faces. Seventeen pond stones have newly authored base
projections. Whole-paint contours from .10 are preserved for render masks.
No source art is modified and no uniform 50%-height rule is used.
"""
from pathlib import Path
import copy,json,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
BASE=ROOT/'output/adventure game 0.1.5.7/collision_profiles.json'
VISUAL=ROOT/'output/adventure game 0.1.5.10/collision_profiles.json'
OUT=ROOT/'output/adventure game 0.1.5.11/collision_profiles.json'
SRC=ROOT/'tests/0.1.5.7/profile-sprites'
DST=ROOT/'tests/0.1.5.11/footprint-authoring'
DST.mkdir(parents=True,exist_ok=True)
base=json.loads(BASE.read_text()); painted=json.loads(VISUAL.read_text())
data=copy.deepcopy(painted)
for key,p in data.items():
 p['visual_polygons']=copy.deepcopy(painted[key]['polygons'])
 p['visual_depth_v']=painted[key]['depth_v']
 p['collision_space']='ground_plane'
 if key in base:
  p['polygons']=copy.deepcopy(base[key]['polygons'])
  p['depth_v']=base[key]['depth_v']
  p['notes']=base[key]['notes']+' 0.1.5.11: physical ground projection only; elevated paint is retained separately in visual_polygons.'

# Each shore stone is authored against its own contact shape. Broad base
# widths differ with stone size/perspective; keep their original index order.
shore={
'pond_0_rocks':[
 [(63,146),(70,139),(83,137),(96,139),(108,145),(110,151),(102,158),(91,162),(76,158),(63,153)],
 [(160,73),(169,65),(185,62),(205,64),(222,61),(238,65),(251,72),(251,76),(238,79),(226,89),(210,91),(194,85),(179,91),(166,83)],
 [(393,101),(398,97),(407,95),(415,99),(414,106),(408,111),(400,107)],
 [(410,126),(416,117),(431,113),(450,112),(467,116),(484,120),(498,131),(490,143),(474,146),(456,151),(441,149),(427,141)],
 [(52,309),(62,298),(80,292),(99,290),(115,295),(131,303),(144,317),(132,329),(114,335),(96,331),(85,324),(68,324)],
 [(197,350),(207,345),(220,344),(233,348),(245,356),(238,363),(225,366),(211,362),(200,358)],
 [(357,354),(366,346),(381,342),(397,340),(414,345),(429,353),(439,369),(427,377),(409,382),(393,378),(379,376),(365,374)]],
'pond_1_rocks':[
 [(191,84),(198,79),(210,77),(222,79),(234,86),(234,92),(223,97),(208,95),(198,92)],
 [(395,116),(406,107),(424,103),(445,105),(464,107),(484,109),(505,116),(509,130),(498,140),(481,148),(462,145),(442,140),(426,137),(406,132)],
 [(36,247),(45,240),(58,239),(70,241),(83,248),(87,258),(75,265),(61,264),(47,260),(36,253)],
 [(72,324),(83,313),(101,306),(122,303),(144,305),(163,313),(184,331),(172,340),(152,345),(134,343),(117,337),(97,340),(82,333)],
 [(188,351),(197,345),(208,342),(222,346),(235,351),(231,361),(219,366),(207,364),(196,359)]],
'pond_2_rocks':[
 [(30,305),(40,294),(58,284),(78,281),(98,282),(117,289),(137,300),(150,308),(148,319),(135,329),(116,333),(99,329),(81,326),(63,329),(45,323)],
 [(269,359),(278,350),(293,342),(311,340),(328,342),(343,351),(354,367),(342,376),(322,381),(303,377),(289,374),(276,370)],
 [(360,203),(370,195),(386,189),(402,189),(419,193),(435,204),(440,210),(432,217),(417,223),(403,222),(388,219),(373,215)],
 [(304,174),(313,170),(325,170),(334,174),(332,179),(322,184),(311,182),(304,178)],
 [(356,236),(363,233),(372,233),(381,236),(385,238),(380,241),(372,244),(363,242),(357,240)]]}
for key,polys in shore.items():
 im=Image.open(SRC/(key.replace('_rocks','')+'.png'))
 w,h=im.size
 data[key]['polygons']=[[[round(x/w,7),round(y/h,7)] for x,y in poly] for poly in polys]
 data[key]['depth_v']=round(max(y for p in polys for x,y in p)/h,7)
 data[key]['notes']='Individually authored stone ground contacts, in unchanged visual_polygons order. Upper stone faces are overhead visual occluders; each physical stone remains independently solid. Pond water is separately blocked.'

# House foundation and stairs were separately rechecked at full native size.
# Retain the ground-volume rear edge, but follow the true oblique front wall
# and protruding lower step rather than the old scalar front-contact line.
# The native lower front stair edge is oblique from(360,475)to(486,428);
# source(396,480) is transparent below it and deliberately remains free.
house_px=[(70,309),(100,285),(135,277),(189,293),(256,304),(327,291),
          (400,269),(450,257),(493,276),(494,351),(482,368),(461,366),
          (459,394),(483,419),(486,428),(477,435),(462,438),(443,445),
          (423,451),(405,460),(383,467),(366,474),(360,475),(350,470),(345,438),(316,421),(294,418),(266,434),(231,420),(212,405),
          (213,393),(185,386),(139,362),(86,325)]
for key in ['cabin','prop_0']:
 data[key]['polygons']=[[[round(x/572,7),round(y/498,7)] for x,y in house_px]]
 data[key]['depth_v']=round(475/498,7)

# More explicit names replace historically ambiguous full-volume comments.
data['cabin']['notes']='Projected closed house foundation with side/front wall ground volume and protruding stairs. Roof, chimney and upper walls are overhead paint, never ground collision. Decorative plants are passable; there is no indoor opening.'
data['prop_0']['notes']=data['cabin']['notes']
data['gate']['notes']='Two irregular pillar ground feet only; center passage and elevated masonry/header remain free. With runtime width156, the raw inner-foot gap is42.12 world units, leaving14.12 units for a28-wide actor.'
data['bench']['notes']='Projected workbench ground volume, independently traced legs and lower brace. Elevated tools, tall rear post and tabletop are visual only. Front gap between feet is concave, not a solid rectangle.'
# Render-only roof/canopy split; physics never reads this metadata. The
# boundary follows each model's grounded rear edge, not a global half-height.
# Water has no elevated paint and must never become translucent.
for key,p in data.items():
 rear_v=min(y for poly in p['polygons'] for x,y in poly)
 if key in ('cabin','prop_0'):rear_v=.55
 if key.startswith('pond_') and not key.endswith('_rocks'):rear_v=0.0
 p['overhead_split_v']=round(rear_v,7)
 if key.endswith('_rocks'):
  p['overhead_split_vs']=[round(min(y for x,y in poly),7) for poly in p['polygons']]
OUT.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

# Independent landmarks selected from art, not sampled from a polygon. Each
# row includes a real occupied base and an overhead region that must be free.
landmarks={
 'tree_0':([(.51,.82)],[(.55,.48),(.70,.63)]),
 'tree_1':([(.50,.83)],[(.49,.42),(.63,.64)]),
 'tree_2':([(.44,.84)],[(.48,.47),(.58,.62)]),
 'tree_3':([(.52,.84)],[(.53,.50),(.72,.61)]),
 'tree_4':([(.49,.85)],[(.46,.41),(.62,.65)]),
 'tree_5':([(.54,.85)],[(.52,.48),(.69,.65)]),
 'shrub_0':([(.50,.81)],[(.50,.44)]),
 'shrub_1':([(.50,.81)],[(.40,.43)]),
 'shrub_2':([(.50,.81)],[(.55,.41)]),
 'shrub_3':([(.50,.81)],[(.52,.40)]),
 'cabin':([(.38,.72),(.72,.84),(.70,.91)],[(.53,.29),(.27,.12)]),
 'prop_0':([(.38,.72),(.72,.84),(.70,.91)],[(.53,.29),(.27,.12)]),
 'prop_1':([(.48,.74)],[(.40,.25)]),
 'prop_2':([(.49,.73)],[(.39,.26)]),
 'prop_3':([(.50,.79)],[(.50,.30)]),
 'prop_4':([(.48,.75)],[(.48,.31)]),
 'prop_5':([(.48,.74)],[(.48,.32)]),
 'bench':([(.23,.86),(.74,.86)],[(.50,.43),(.26,.19)]),
 'stump_0':([(.49,.73)],[(.48,.25)]),
 'stump_1':([(.52,.74)],[(.55,.33)]),
 'ore_0':([(.60,.73),(.29,.83)],[(.65,.36)]),
 'ore_1':([(.60,.74),(.26,.79)],[(.52,.32)]),
 'ore_2':([(.59,.75),(.24,.80)],[(.61,.43)]),
 'resource_branch_0':([(.56,.84)],[(.50,.39)]),
 'resource_branch_1':([(.35,.77)],[(.61,.37)]),
 'resource_branch_2':([(.53,.85)],[(.51,.42)]),
 'resource_rock_0':([(.40,.76),(.73,.82)],[(.49,.25)]),
 'resource_rock_1':([(.37,.77),(.66,.88)],[(.48,.37)]),
 'resource_rock_2':([(.61,.75),(.28,.79)],[(.57,.35)]),
 'resource_rope_0':([(.49,.84)],[(.42,.41)]),
 'resource_rope_1':([(.48,.83)],[(.48,.39)]),
 'resource_rope_2':([(.50,.86)],[(.49,.45)]),
 'resource_branch_spent_0':([(.48,.75)],[(.58,.39)]),
 'resource_branch_spent_1':([(.48,.74)],[(.63,.39)]),
 'resource_branch_spent_2':([(.50,.74)],[(.44,.32)]),
 'resource_rock_spent_0':([(.18,.78),(.47,.78),(.76,.78)],[(.47,.38)]),
 'resource_rock_spent_1':([(.40,.70),(.53,.84)],[(.48,.30)]),
 'resource_rock_spent_2':([(.35,.76),(.68,.80),(.39,.89)],[(.36,.40)]),
 'resource_rope_spent_0':([(.49,.77)],[(.49,.31)]),
 'resource_rope_spent_1':([(.49,.78)],[(.34,.27)]),
 'resource_rope_spent_2':([(.49,.77)],[(.45,.34)]),
 'gate':([(.22,.75),(.73,.84)],[(.33,.30),(.70,.40),(.47,.60),(.47,.80)]),
 'pond_0':([(.50,.55)],[(.04,.05)]),
 'pond_1':([(.50,.55)],[(.04,.05)]),
 'pond_2':([(.50,.55)],[(.04,.05)])}
# Independent contact labels for all17 rocks, no polygon-centroid selection.
shore_solids={
 'pond_0_rocks':[(88,150),(202,78),(406,103),(452,135),(101,313),(222,355),(399,366)],
 'pond_1_rocks':[(213,88),(456,126),(61,253),(130,328),(212,356)],
 'pond_2_rocks':[(88,313),(315,363),(401,208),(321,177),(370,238)]}
shore_overhead={
 'pond_0_rocks':[(86,128),(203,35),(408,87),(451,89),(99,274),(219,337),(395,328)],
 'pond_1_rocks':[(212,62),(462,67),(57,227),(126,280),(213,333)],
 'pond_2_rocks':[(84,253),(320,322),(403,170),(322,163),(371,229)]}
for key in shore:
 w,h=Image.open(SRC/(key.replace('_rocks','')+'.png')).size
 landmarks[key]=([(x/w,y/h) for x,y in shore_solids[key]],[(x/w,y/h) for x,y in shore_overhead[key]])

def inside(p,poly):
 x,y=p; yes=False
 for i,a in enumerate(poly):
  b=poly[(i+1)%len(poly)]
  if ((a[1]>y)!=(b[1]>y)) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:yes=not yes
 return yes
samples={}; failures=[]; checks=0
for key,(solids,free) in landmarks.items():
 samples[key]={'solid_uv':solids,'overhead_free_uv':free}
 for p in solids:
  checks+=1
  if not any(inside(p,poly) for poly in data[key]['polygons']):failures.append([key,'solid',p])
 for p in free:
  checks+=1
  if any(inside(p,poly) for poly in data[key]['polygons']):failures.append([key,'overhead_free',p])
(DST/'art-landmarks.json').write_text(json.dumps(samples,indent=2)+'\n')

# Source-native overlays distinguish physical contact (coral) from .10
# elevated visual outline (blue). Green landmark = a free overhead pixel.
thumbs=[]
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',15)
for key,p in data.items():
 sprite=key.replace('_rocks','')
 im=Image.open(SRC/(sprite+'.png')).convert('RGBA')
 w,h=im.size
 bg=Image.new('RGBA',(w,h),(215,225,204,255));bg.alpha_composite(im)
 dr=ImageDraw.Draw(bg)
 for n in range(1,10):
  dr.line((w*n/10,0,w*n/10,h),fill=(135,150,130,110));dr.line((0,h*n/10,w,h*n/10),fill=(135,150,130,110))
 for poly in p['visual_polygons']:
  xy=[(x*w,y*h) for x,y in poly];dr.line(xy+[xy[0]],fill=(70,120,215,210),width=2)
 for i,poly in enumerate(p['polygons']):
  xy=[(x*w,y*h) for x,y in poly]
  overlay=Image.new('RGBA',(w,h));od=ImageDraw.Draw(overlay);od.polygon(xy,fill=(250,85,65,55));bg=Image.alpha_composite(bg,overlay);dr=ImageDraw.Draw(bg);dr.line(xy+[xy[0]],fill=(235,60,50,255),width=3)
 for x,y in samples[key]['solid_uv']:
  x*=w;y*=h;dr.ellipse((x-4,y-4,x+4,y+4),fill=(245,35,35),outline='white',width=1)
 for x,y in samples[key]['overhead_free_uv']:
  x*=w;y*=h;dr.ellipse((x-4,y-4,x+4,y+4),fill=(35,210,65),outline='white',width=1)
 bg.convert('RGB').save(DST/(key+'.png'))
 tile=Image.new('RGB',(256,286),(235,238,227));thumb=bg.convert('RGB');thumb.thumbnail((248,250));tile.paste(thumb,((256-thumb.width)//2,28+(250-thumb.height)//2));d=ImageDraw.Draw(tile);d.text((8,6),key,font=font,fill=(25,35,25));thumbs.append(tile)
cols=6;rows=math.ceil(len(thumbs)/cols)
contact=Image.new('RGB',(cols*256,rows*286),(235,238,227))
for i,im in enumerate(thumbs):contact.paste(im,((i%cols)*256,(i//cols)*286))
contact.save(DST/'all-48-ground-footprints.jpg',quality=94)
result={'profiles':len(data),'physical_polygons':sum(len(p['polygons']) for p in data.values()),'visual_polygons':sum(len(p['visual_polygons']) for p in data.values()),'shore_stones':sum(len(p) for p in shore.values()),'landmark_checks':checks,'failures':failures,'source_art_modified':False,'visual_contours_preserved':all(data[k]['visual_polygons']==painted[k]['polygons'] for k in data)}
(DST/'authoring-results.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
if failures:raise SystemExit(1)
