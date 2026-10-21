import json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
out=root/'tests/0.1.6/footprint-audit';out.mkdir(exist_ok=True)
release=root/'output/adventure game 0.1.6'
meta=json.loads((release/'assets/animal_atlas.json').read_text())['species']
old={'rabbit':(8,4),'deer':(15,6),'fox':(13,5),'wolf':(17,7),'bear':(26,11)}
authored=json.loads((out/'heading-ground-profiles.json').read_text()) if (out/'heading-ground-profiles.json').exists() else None
for species,m in meta.items():
    atlas=Image.open(release/m['path'].removeprefix('res://')).convert('RGBA')
    board=Image.new('RGBA',(8*240,4*240),(235,232,216,255));d=ImageDraw.Draw(board)
    scale=m['world_height']/m['reference_height_px']
    for direction in range(8):
        for frame in range(4):
            col,row=direction*240,frame*240
            r=m['poses'][direction][frame]['source_rect'];crop=atlas.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
            # Runtime zoom x2 for inspection, preserving relative world dimensions.
            size=round(384*scale*2);crop=crop.resize((size,size),Image.Resampling.LANCZOS)
            anchor=(m['anchor'][0]*scale*2,m['anchor'][1]*scale*2)
            origin=(col+120-anchor[0],row+204-anchor[1]);board.alpha_composite(crop,(round(origin[0]),round(origin[1])))
            if authored:
                ground=authored[species][direction];ox,oy=ground['offset'];rx,ry=ground['half_size']
                center=(col+120+ox*2,row+204+oy*2)
            else:
                center=(col+120,row+202);rx,ry=old[species]
            pts=[];ext=max(0,rx-ry)
            for i in range(17):
                a=-math.pi/2+math.pi*i/16;pts.append((center[0]+(ext+math.cos(a)*ry)*2,center[1]+math.sin(a)*ry*2))
            for i in range(17):
                a=math.pi/2+math.pi*i/16;pts.append((center[0]+(-ext+math.cos(a)*ry)*2,center[1]+math.sin(a)*ry*2))
            d.line(pts+[pts[0]],fill=(0,130,100) if authored else (220,40,50),width=2)
            if authored:
                for px,py in ground['paws']:
                    d.ellipse((col+120+px*2-2,row+204+py*2-2,col+120+px*2+2,row+204+py*2+2),fill=(225,80,40))
            d.line([(col+120,row+190),(col+120,row+216)],fill=(0,110,160),width=1)
            d.line([(col+105,row+204),(col+135,row+204)],fill=(0,110,160),width=1)
            for wx in [-40,-20,0,20,40]:
                if wx==0:continue
                d.line([(col+120+wx*2,row+196),(col+120+wx*2,row+210)],fill=(90,120,100),width=1)
                d.text((col+120+wx*2-8,row+218),str(wx),fill=(30,70,50))
            d.text((col+8,row+8),f'{species} {direction*45}deg / frame {frame}',fill=(30,50,30))
    suffix='authored-heading-ground-capsules' if authored else 'current-ground-capsules'
    board.convert('RGB').save(out/f'{species}-{suffix}.jpg',quality=93)
