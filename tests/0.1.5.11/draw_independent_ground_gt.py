from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
base=Path(__file__).resolve().parent;src=base.parent/'0.1.5.7/profile-sprites'
doc=json.loads((base/'independent-ground-landmarks.json').read_text())
groups={}
for point in doc['samples']:groups.setdefault(point['profile'],[]).append(point)
font=ImageFont.load_default(size=17);small=ImageFont.load_default(size=13)
canvas=Image.new('RGB',(1800,2100),(234,229,208));d=ImageDraw.Draw(canvas)
d.text((15,12),'Independent source-art landmarks: RED = ground solid; BLUE = overhead / soft / ground foliage',fill=(28,47,34),font=font)
for i,(profile,points) in enumerate(groups.items()):
 n=profile.replace('_rocks','');sprite=Image.open(src/(n+'.png')).convert('RGBA');w,h=sprite.size;ratio=min(270/w,208/h);size=(round(w*ratio),round(h*ratio));sprite=sprite.resize(size,Image.Resampling.LANCZOS)
 x=i%6*300+15+(270-size[0])//2;y=i//6*255+60+(208-size[1])//2
 canvas.paste(sprite,(x,y),sprite);d.text((i%6*300+10,i//6*255+41),profile,fill=(0,0,0),font=font)
 for j,point in enumerate(points):
  px=x+point['source_px'][0]*ratio;py=y+point['source_px'][1]*ratio;c=(220,55,33) if point['expect']=='solid' else (28,89,225)
  d.ellipse((px-4,py-4,px+4,py+4),outline=c,width=2);d.text((px+4,py-12),str(j+1),fill=c,font=small)
canvas.save(base/'independent-ground-landmarks.jpg',quality=94)
