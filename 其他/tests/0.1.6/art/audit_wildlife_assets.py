"""Independent asset audit + native-pixel direction contact sheet. No generation."""
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import numpy as np, json, hashlib
P=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
A=P/'output/adventure game 0.1.6/assets'
T=P/'tests/0.1.6/art'
O=P/'素材整理/动物/0.1.6/originals'
D=json.loads((A/'animal_atlas.json').read_text())
mapping={
 'exec-7299126d-a7d1-47a6-944e-89f5c73dc7ca.png':'rabbit-native-generated.png',
 'exec-e88c9123-9ac0-43de-b52a-e57e355e5f5d.png':'deer-native-generated.png',
 'exec-cb036d13-54d4-4caf-9f45-0ce74cfe72ef.png':'fox-native-generated.png',
 'exec-6af033d1-aae0-4b23-8135-820adc01a68f.png':'fox-southeast-repair-native-generated.png',
 'exec-8bc062ff-a4f0-442e-8c3e-38b27369648a.png':'wolf-native-generated.png',
 'exec-19b55d29-da9b-4133-b43c-25d33f654154.png':'bear-native-generated.png'
}
font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',23)
board=Image.new('RGB',(2560,5*272+42),(117,151,105))
draw=ImageDraw.Draw(board)
for d,label in enumerate(['S','SE','E','NE','N','NW','W','SW']):
 draw.text((d*320+148,10),label,font=font,fill=(244,235,208))
checks=0;rows=[]
for si,(species,spec) in enumerate(D['species'].items()):
 im=Image.open(A/f'wildlife-{species}.png').convert('RGBA')
 assert list(im.size)==[3072,1536];checks+=1
 for d in range(8):
  hashes=[]
  for f in range(4):
   p=spec['poses'][d][f];sr=p['source_rect']
   cell=im.crop((sr[0],sr[1],sr[0]+sr[2],sr[1]+sr[3]))
   expected=Image.open(O/mapping[p['native_source_file']]).convert('RGBA').crop(p['native_source_crop'])
   x,y=p['native_paste']
   actual=cell.crop((x,y,x+expected.width,y+expected.height))
   assert np.array_equal(np.asarray(actual),np.asarray(expected)),(species,d,f);checks+=1
   arr=np.asarray(cell)
   assert not np.any(arr[0,:,3]) and not np.any(arr[-1,:,3]) and not np.any(arr[:,0,3]) and not np.any(arr[:,-1,3]);checks+=1
   assert p['anchor']==[192,320];checks+=1
   # Detect high-opacity pure red/yellow bogus mattes independently of preview renderer.
   assert not np.any((arr[:,:,0]>220)&(arr[:,:,1]<30)&(arr[:,:,3]>10));checks+=1
   assert not np.any((arr[:,:,0]>230)&(arr[:,:,1]>230)&(arr[:,:,2]<30)&(arr[:,:,3]>10));checks+=1
   hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
  assert len(set(hashes))==4,(species,d);checks+=1
  p=spec['poses'][d][0];sr=p['source_rect']
  cell=im.crop((sr[0]+32,sr[1]+94,sr[0]+352,sr[1]+330))
  board.paste(cell,(d*320,si*272+62),cell)
 draw.text((8,si*272+42),species.upper(),font=font,fill=(244,235,208))
 rows.append({'species':species,'directions':8,'distinct_walk_keys_per_direction':4,'native_crop_matches':32,'world_height':spec['world_height'],'reference_height_px':spec['reference_height_px']})
board.save(T/'all-eight-directions-native.png')
(T/'asset-audit.json').write_text(json.dumps({'checks':checks,'all_passed':True,'species':rows,'transparency':'Native RGBA alpha composited correctly has no red/yellow matte. Transparent tool preview may expose hidden RGB of near-zero-alpha pixels. Black/green opaque proof images are provided.','limitations':'Hand-painted separate keyframes have small natural shape variations; anatomy/directions visually reviewed. Gait has four discrete keys, not a continuous rig.'},indent=2)+'\n')
print(json.dumps({'checks':checks,'species':len(rows),'poses':160,'all_passed':True}))

