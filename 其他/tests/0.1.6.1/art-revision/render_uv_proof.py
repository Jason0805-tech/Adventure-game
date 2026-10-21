"""Render the TEST prototype's original-painted UV mesh; never writes runtime art."""
from pathlib import Path
import json,math
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[3];TEST=ROOT/'tests/0.1.6.1/art-revision'
D=json.loads((TEST/'uv-proof-geometry.json').read_text())
font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',17)
def cross(a,b):return a[...,0]*b[...,1]-a[...,1]*b[...,0]
def render(species,points):
 src=np.array(Image.open(ROOT/'output/adventure game 0.1.6/assets'/('wildlife-'+species+'.png')).convert('RGBA'))[:,768:1152][:384]/255.
 source=np.array(D[species]['source_points']);target=np.array(points);inds=np.array(D[species]['indices']).reshape(-1,3)
 out=np.zeros((384,384,4),dtype=float)
 for ix in inds:
  uv=source[ix];tri=target[ix];area=cross(tri[1]-tri[0],tri[2]-tri[0])
  if abs(area)<1e-7:continue
  # Cull fully transparent source texels; their world-space folds cannot paint.
  sx0=max(0,int(uv[:,0].min()));sx1=min(384,int(uv[:,0].max())+1)
  sy0=max(0,int(uv[:,1].min()));sy1=min(384,int(uv[:,1].max())+1)
  if src[sy0:sy1,sx0:sx1,3].max()<.001:continue
  if area<0:tri=tri[[0,2,1]];uv=uv[[0,2,1]];area=-area
  x0=max(0,math.floor(tri[:,0].min()));x1=min(384,math.ceil(tri[:,0].max()))
  y0=max(0,math.floor(tri[:,1].min()));y1=min(384,math.ceil(tri[:,1].max()))
  if x1<=x0 or y1<=y0:continue
  yy,xx=np.mgrid[y0:y1,x0:x1];xy=np.stack((xx+.5,yy+.5),axis=-1)
  edges=[tri[1]-tri[0],tri[2]-tri[1],tri[0]-tri[2]]
  e=[cross(edge,xy-tri[i]) for i,edge in enumerate(edges)]
  mask=np.ones(xx.shape,dtype=bool)
  for edge,edgev in zip(edges,e):
   top_left=edge[1]<0 or(abs(edge[1])<1e-8 and edge[0]>0)
   mask&=(edgev>1e-7)|((abs(edgev)<=1e-7)&top_left)
  if not mask.any():continue
  bary=np.stack((e[1],e[2],e[0]),axis=-1)/area
  coords=bary@uv;u=np.clip(np.floor(coords[...,0]).astype(int),0,383);v=np.clip(np.floor(coords[...,1]).astype(int),0,383)
  pixels=src[v,u];alpha=pixels[...,3:4]
  targetregion=out[y0:y1,x0:x1]
  blend=np.empty_like(pixels);blend[...,:3]=pixels[...,:3]*alpha+targetregion[...,:3]*(1-alpha);blend[...,3:4]=alpha+targetregion[...,3:4]*(1-alpha)
  targetregion[mask]=blend[mask]
 rgba=out.copy();rgba[...,:3]=np.divide(rgba[...,:3],rgba[...,3:4],out=np.zeros_like(rgba[...,:3]),where=rgba[...,3:4]>.0001)
 return Image.fromarray((np.clip(rgba,0,1)*255).round().astype('uint8'),'RGBA')
def composite(im):
 bg=Image.new('RGB',(384,384),(184,200,151));bg.paste(im,(0,0),im);return bg
allframes={}
for species in D:
 print('UV_RENDER',species,flush=True)
 idle=render(species,D[species]['idle_points']);idle.save(TEST/(species+'-native-painted-idle.png'))
 frames=[render(species,p) for p in D[species]['frames']]
 allframes[species]=frames
 frames[0].save(TEST/(species+'-native-painted-frame.png'))
 frames[0].save(TEST/(species+'-native-painted.gif'),save_all=True,append_images=frames[1:],duration=50,loop=0,disposal=2)
sheet=Image.new('RGB',(6*320,2*330),(184,200,151));dr=ImageDraw.Draw(sheet)
for row,species in enumerate(D):
 for col,f in enumerate([0,4,8,12,16,20]):
  im=allframes[species][f].crop((20,105,355,365)).resize((300,235),Image.Resampling.LANCZOS)
  sheet.paste(im,(col*320+10,row*330+60),im)
  dr.text((col*320+10,row*330+16),species.title()+' original paint '+str(f)+'/24',font=font,fill=(37,59,42))
sheet.save(TEST/'native-painted-legs-proof.jpg',quality=96)
# Side by side actual original idle and UV idle: no new boot/limb paint.
rest=Image.new('RGB',(800,500),(184,200,151));dr=ImageDraw.Draw(rest)
for row,s in enumerate(D):
 original=Image.open(ROOT/'output/adventure game 0.1.6/assets'/('wildlife-'+s+'.png')).crop((768,0,1152,384))
 uv=Image.open(TEST/(s+'-native-painted-idle.png'))
 for col,im in enumerate([original,uv]):
  im=im.crop((20,110,355,365)).resize((335,255),Image.Resampling.LANCZOS)
  rest.paste(im,(col*400+20,row*250),im)
  dr.text((col*400+20,row*250+12),s+(' original .6' if col==0 else ' original-UV rest'),font=font,fill=(37,59,42))
rest.save(TEST/'original-vs-native-uv-idle.jpg',quality=96)
print('UV_PROOF_PREVIEWS_READY',TEST)
