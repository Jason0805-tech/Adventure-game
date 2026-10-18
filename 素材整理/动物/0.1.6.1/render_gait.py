"""Software render of the release's own Canvas-rig geometry for visual QA.
Uses unmodified production RGBA body paint, clipped by the exact runtime polygon.
This is not a native-GPU screenshot or new artwork.
"""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3]
TEST=ROOT/'tests/0.1.6.1/gait';DATA=json.loads((TEST/'gait-geometry.json').read_text())
FONT=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',15)
SMALL=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',12)
SOURCES={s:Image.open(ROOT/'output/adventure game 0.1.6.1/assets'/Path(v['metadata']['path']).name).convert('RGBA') for s,v in DATA['species'].items()}
def pose(s,d,f,zoom=1):
 m=DATA['species'][s];p=m['directions'][d][f];sc=m['scale'];size=384*zoom
 out=Image.new('RGBA',(size,size));dr=ImageDraw.Draw(out)
 for poly in p['limbs']:
  pts=[(x/sc*zoom,y/sc*zoom)for x,y in poly['points']]
  color=tuple(round(v*255) for v in poly['color'])
  xmin=max(0,math.floor(min(x for x,y in pts)));ymin=max(0,math.floor(min(y for x,y in pts)))
  xmax=min(size,math.ceil(max(x for x,y in pts))+1);ymax=min(size,math.ceil(max(y for x,y in pts))+1)
  if xmax>xmin and ymax>ymin:
   paint=Image.new('RGBA',(xmax-xmin,ymax-ymin));ImageDraw.Draw(paint).polygon([(x-xmin,y-ymin)for x,y in pts],fill=color);out.alpha_composite(paint,(xmin,ymin))
 texture=SOURCES[s].crop((d*384,0,(d+1)*384,384))
 if zoom!=1:texture=texture.resize((size,size),Image.Resampling.LANCZOS)
 mask=Image.new('L',(size,size));md=ImageDraw.Draw(mask)
 pts=[(x/sc*zoom,y/sc*zoom)for x,y in p['body_points']];md.polygon(pts,fill=255)
 dy=p['body_bob']*zoom
 canvas=Image.new('RGBA',(size,size));canvas.alpha_composite(texture,(0,round(dy)))
 alpha=canvas.getchannel('A');import PIL.ImageChops
 canvas.putalpha(PIL.ImageChops.multiply(alpha,mask));out.alpha_composite(canvas)
 return out
# Native-size art views: all five species and all 8 registered headings.
w,h=8*250,5*260
sheet=Image.new('RGB',(w,h),(198,208,168));dr=ImageDraw.Draw(sheet)
for row,s in enumerate(DATA['species']):
 for d in range(8):
  im=pose(s,d,3).crop((25,105,350,365)).resize((250,200),Image.Resampling.LANCZOS)
  x=d*250;y=row*260
  sheet.paste(im,(x,y+35),im);dr.text((x+10,y+8),s.title()+' '+str(d*45)+'°',font=FONT,fill=(37,62,47))
sheet.save(TEST/'articulated-all-headings.jpg',quality=94)
# Forward-only time sequence; all source phases exactly match runtime geometry.
frames=[]
for f in range(24):
 image=Image.new('RGB',(900,850),(114,144,95));dr=ImageDraw.Draw(image)
 for row,s in enumerate(DATA['species']):
  for col,d in enumerate([0,1,2]):
   x=col*300;y=row*170
   dr.rectangle((x+4,y+4,x+296,y+166),fill=(189,203,155))
   dr.text((x+10,y+8),s.title()+'  '+['S','SE','E'][col],font=FONT,fill=(39,62,43))
   # Body translated steadily forward over a textured ruler. The whole cycle
   # travels its registered projected stride, then wraps only the demonstration.
   sc=DATA['species'][s]['scale'];stride=DATA['species'][s]['metadata']['gait']['stride_world']
   im=pose(s,d,f).crop((25,115,350,370))
   display=0.48 if s in ['deer','bear'] else .50
   im=im.resize((round(im.width*display),round(im.height*display)),Image.Resampling.LANCZOS)
   phase=f/24
   shiftx=math.sin(math.radians(d*45))*stride/sc*phase*display
   shifty=math.cos(math.radians(d*45))*.30*stride/sc*phase*display
   for tick in range(6):dr.line((x+30+tick*43,y+145,x+30+tick*43,y+151),fill=(113,143,83),width=2)
   image.paste(im,(round(x+40+shiftx),round(y+25+shifty)),im)
 dr.text((10,832),'Forward phase %02d / 24  |  body identity fixed  |  native painted body + articulated 2D limbs'%(f+1),font=SMALL,fill=(241,238,204))
 frames.append(image)
frames[0].save(TEST/'sequential-locomotion.gif',save_all=True,append_images=frames[1:],duration=45,loop=0,optimize=True)
frames[3].save(TEST/'sequential-locomotion-frame.png')
# Readable contact sequences across one lateral walking cycle.
contact=Image.new('RGB',(6*300,5*230),(199,211,173));dr=ImageDraw.Draw(contact)
for row,s in enumerate(DATA['species']):
 for col,f in enumerate([0,4,8,12,16,20]):
  im=pose(s,2,f).crop((20,115,355,365)).resize((268,200),Image.Resampling.LANCZOS)
  x=col*300;y=row*230;contact.paste(im,(x+10,y+27),im)
  dr.text((x+10,y+6),s.title()+'  phase '+str(f)+'/24',font=FONT,fill=(35,58,40))
contact.save(TEST/'sequential-contact-sheet.jpg',quality=94)
print('GAIT_PREVIEWS_READY',TEST)
