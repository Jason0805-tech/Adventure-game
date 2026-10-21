"""QA-only approximate trilinear presentation of actual Godot-exported mip data.
No source or production asset is modified or resampled.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np, json, math
P=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
T=P/'tests/0.1.6/art/mip-qa';A=P/'output/adventure game 0.1.6/assets'
meta=json.loads((A/'animal_atlas.json').read_text())['species']
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',19)
small=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',15)

def linear(a,x,y):
 x=np.clip(x,0,a.shape[1]-1);y=np.clip(y,0,a.shape[0]-1)
 ix=np.floor(x).astype(int);iy=np.floor(y).astype(int)
 fx=x-ix;fy=y-iy
 jx=np.minimum(ix+1,a.shape[1]-1);jy=np.minimum(iy+1,a.shape[0]-1)
 return (a[iy,ix]*(1-fx[...,None])*(1-fy[...,None])+a[iy,jx]*fx[...,None]*(1-fy[...,None])+a[jy,ix]*(1-fx[...,None])*fy[...,None]+a[jy,jx]*fx[...,None]*fy[...,None])

def presentation(mips,scale,d=2,f=0):
 lod=max(0,-math.log2(scale));lo=int(math.floor(lod));frac=lod-lo
 w=int(math.ceil(384*scale));h=w
 yy,xx=np.mgrid[:h,:w]
 def at(level):
  factor=2**level
  x=((xx+.5)/scale+d*384)/factor-.5
  y=((yy+.5)/scale+f*384)/factor-.5
  return linear(mips[level],x,y)
 rgba=at(lo)*(1-frac)+at(min(lo+1,3))*frac
 return rgba, lod
def composite(a,bg):
 return np.clip(a[:,:,:3]*255*a[:,:,3:4]+np.array(bg)[None,None,:]*(1-a[:,:,3:4]),0,255).astype(np.uint8)
board=Image.new('RGB',(1400,800),(239,228,201));draw=ImageDraw.Draw(board)
draw.text((22,16),'ACTUAL GODOT load_texture → fix_alpha_edges → MIPMAPS',font=font,fill=(47,62,54))
draw.text((22,44),'QA software bilinear/trilinear sampling of exported mip data; 1× game scale above, 4× detail below.',font=small,fill=(47,62,54))
stats={}
for i,(name,spec) in enumerate(meta.items()):
 src=np.asarray(Image.open(A/f'wildlife-{name}.png').convert('RGBA'))
 images=[np.asarray(Image.open(T/f'{name}-mip{j}.png').convert('RGBA')).astype(float)/255 for j in range(4)]
 lvl0=np.round(images[0]*255).astype(np.uint8)
 samealpha=bool(np.array_equal(src[:,:,3],lvl0[:,:,3]))
 op=src[:,:,3]>=250
 opaqueunchanged=bool(np.array_equal(src[:,:,:3][op],lvl0[:,:,:3][op]))
 unusual=[]
 for j,a in enumerate(images):
  unusual.append(int(((a[:,:,0]>.90)&(a[:,:,1]<.13)&(a[:,:,3]>.03)).sum()))
 scale=spec['world_height']/spec['reference_height_px']
 rgba,lod=presentation(images,scale)
 stats[name]={'scale':scale,'expected_lod':lod,'base_alpha_exact':samealpha,
   'opaque_paint_rgb_alpha_ge250_exact':opaqueunchanged,'high_red_alpha_gt3percent_by_mip':unusual}
 assert samealpha and opaqueunchanged and unusual==[0]*4,(name,stats[name])
 x=i*280
 draw.text((x+15,80),name.upper()+' / LOD %.2f'%lod,font=font,fill=(47,62,54))
 for row,(label,bg) in enumerate([('DAY / MEADOW',(113,149,79)),('NIGHT / BLUE',(23,37,57))]):
  y=115+row*340
  draw.rectangle((x+8,y,x+272,y+308),fill=bg)
  draw.text((x+16,y+8),label,font=small,fill=(245,239,216))
  b=composite(rgba,bg)
  sim=Image.fromarray(b)
  board.paste(sim,(x+(280-sim.width)//2,y+36))
  # Center native-size present paint into a 4x nearest detail: no smoothing to hide halo.
  aa=rgba[:,:,3];yy,xx=np.nonzero(aa>.03)
  bb=(max(0,int(xx.min())-2),max(0,int(yy.min())-2),min(sim.width,int(xx.max())+3),min(sim.height,int(yy.max())+3))
  detail=sim.crop(bb)
  # QA zoom can clip giantbearbody if4x exceeds panel; only160px viewport.
  zoom=detail.resize((detail.width*4,detail.height*4),Image.Resampling.NEAREST)
  if zoom.width>248:
   left=(zoom.width-248)//2;zoom=zoom.crop((left,0,left+248,zoom.height))
  if zoom.height>160:
   top=max(0,zoom.height-160);zoom=zoom.crop((0,top,zoom.width,top+160))
  board.paste(zoom,(x+(280-zoom.width)//2,y+142))
board.save(T/'actual-mips-worldscale-day-night.png')
(T/'mip-alpha-audit.json').write_text(json.dumps({'all_passed':True,'method':'Actual game.load_texture output mip levels exported by headless Godot4.7.2. QA software trilinear sample of actual level data onto meadowgreen/nightblue backgrounds. This is not native GPU readback. Native source files unchanged.','species':stats},indent=2)+'\n')
print(json.dumps(stats))

