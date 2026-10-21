from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[3];T=Path(__file__).resolve().parent
old=R/'output/adventure game 0.1.5.9/assets';new=R/'output/adventure game 0.1.5.10/assets'
# Diagnostics at a common 2x viewing size; same pose, not a new pose or artwork.
canvas=Image.new('RGB',(1536,1170),'#dde4cc');d=ImageDraw.Draw(canvas)
actors=[('traveler-armed-directions.png','PLAYER',16,[0,2,4,8]),('npc-rowan-directions.png','ROWAN',8,[0,1,2,4]),('npc-ash-directions.png','ASH',8,[0,1,2,4])]
for row,(name,label,count,dirs) in enumerate(actors):
 d.text((12,row*390+12),label+'   |   .9 old atlas (left) / .10 native render (right) in each pair; common 2x viewing size',fill='#213d36')
 for col,di in enumerate(dirs):
  for version,base,pixel_scale in [(0,old,1),(1,new,2)]:
   atlas=Image.open(base/name).convert('RGBA');w,h=96*pixel_scale,160*pixel_scale;f=2
   crop=atlas.crop((di*w,f*h,(di+1)*w,(f+1)*h)).resize((192,320),Image.Resampling.LANCZOS)
   pos=(col*384+version*192,row*390+48)
   canvas.paste(crop,pos,crop)
   d.text((pos[0]+12,pos[1]+320),'.9' if version==0 else '.10',fill='#213d36')
canvas.save(T/'actor-quality-before-after.png')
print(T/'actor-quality-before-after.png')
