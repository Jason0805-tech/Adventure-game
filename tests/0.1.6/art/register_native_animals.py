"""Register native generated wildlife poses without resampling or painting pixels.
Only crop, integer translate, preserve alpha and pad, plus compose QA previews.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json, shutil, hashlib
from collections import defaultdict

PROJECT=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
ART=PROJECT/'tests/0.1.6/art'
ARCHIVE=PROJECT/'素材整理/动物/0.1.6'
DEST=PROJECT/'output/adventure game 0.1.6/assets'
GEN=Path('/Users/jasonsmacair/.codex/generated_images/01a144cd-31d6-7451-89c2-2c142531bca1')
SOURCE={
 'rabbit':'exec-7299126d-a7d1-47a6-944e-89f5c73dc7ca.png',
 'deer':'exec-e88c9123-9ac0-43de-b52a-e57e355e5f5d.png',
 'fox':'exec-cb036d13-54d4-4caf-9f45-0ce74cfe72ef.png',
 'wolf':'exec-8bc062ff-a4f0-442e-8c3e-38b27369648a.png',
 'bear':'exec-19b55d29-da9b-4133-b43c-25d33f654154.png',
}
HEIGHT={'rabbit':32,'deer':70,'fox':42,'wolf':48,'bear':76}
STRIDE={'rabbit':40,'deer':70,'fox':55,'wolf':60,'bear':75}
COLS={name:list(range(8)) for name in SOURCE}
FOX_SE_REPAIR='exec-6af033d1-aae0-4b23-8135-820adc01a68f.png'
CELL=384
ANCHOR=(192,320)

def components(mask):
    # Run-length connected-component labelling. Alpha not changed by this analysis.
    parent=[];runs=[];prev=[]
    def find(x):
        while parent[x]!=x:
            parent[x]=parent[parent[x]];x=parent[x]
        return x
    def union(a,b):
        a,b=find(a),find(b)
        if a!=b:parent[b]=a
    for y,row in enumerate(mask):
        changes=np.flatnonzero(np.diff(np.r_[False,row,False]))
        current=[]
        for x0,x1 in changes.reshape(-1,2):
            idx=len(parent);parent.append(idx)
            runs.append((y,int(x0),int(x1),idx))
            for px0,px1,pidx in prev:
                if px1>=x0 and px0<=x1:union(idx,pidx)
            current.append((int(x0),int(x1),idx))
        prev=current
    groups=defaultdict(list)
    for y,x0,x1,idx in runs:groups[find(idx)].append((y,x0,x1))
    output=[]
    for rr in groups.values():
        count=sum(x1-x0 for y,x0,x1 in rr)
        if count<600:continue
        xmin=min(x0 for y,x0,x1 in rr);xmax=max(x1 for y,x0,x1 in rr)
        ymin=min(y for y,x0,x1 in rr);ymax=max(y for y,x0,x1 in rr)+1
        output.append(dict(bbox=[xmin,ymin,xmax,ymax],pixels=count,
             center=[sum((x0+x1)*.5*(x1-x0) for y,x0,x1 in rr)/count,
                     sum(y*(x1-x0) for y,x0,x1 in rr)/count]))
    return sorted(output,key=lambda c:c['pixels'],reverse=True)

def main():
    for p in [ART,ARCHIVE/'originals',ARCHIVE/'production',DEST]:p.mkdir(parents=True,exist_ok=True)
    data={'version':'0.1.6','format':'native-rgba-registered-grid-v1',
       'direction_convention':'0=S,45=SE,90=E,135=NE,180=N,225=NW,270=W,315=SW',
       'frame_sequence':'contact-A,passing-A,contact-B,passing-B; rabbit crouch,push,hop,land',
       'registration':'Native source pixels cropped and integer-translated onto transparent padding; no resampling. Fixed anchor for all poses. Independent painted leg keys, no limb rotation.',
       'species':{}}
    report={}
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',26)
    sheet=Image.new('RGB',(1600,490),(239,228,201));d=ImageDraw.Draw(sheet)
    d.text((32,20),'FOREST WANDERER 0.1.6  /  WOODLAND WILDLIFE',font=font,fill=(51,69,55))
    strip=Image.new('RGB',(1600,5*260),(117,151,105));sd=ImageDraw.Draw(strip)
    gif_species=[]
    for i,(name,filename) in enumerate(SOURCE.items()):
        src=GEN/filename;im=Image.open(src).convert('RGBA');arr=np.asarray(im)
        shutil.copy2(src,ARCHIVE/'originals'/f'{name}-native-generated.png')
        cc=components(arr[:,:,3]>=64)
        cc=cc[:32]
        assert len(cc)==32,(name,len(cc))
        cc.sort(key=lambda c:c['center'][1])
        rows=[]
        for r in range(4):
            rr=sorted(cc[r*8:(r+1)*8],key=lambda c:c['center'][0])
            rows.append(rr)
        repaired_rows=None
        repaired_im=None
        if name=='fox':
            repaired_im=Image.open(GEN/FOX_SE_REPAIR).convert('RGBA')
            shutil.copy2(GEN/FOX_SE_REPAIR,ARCHIVE/'originals/fox-southeast-repair-native-generated.png')
            repaired_cc=components(np.asarray(repaired_im)[:,:,3]>=64)[:32]
            assert len(repaired_cc)==32
            repaired_cc.sort(key=lambda c:c['center'][1])
            repaired_rows=[sorted(repaired_cc[r*8:(r+1)*8],key=lambda c:c['center'][0]) for r in range(4)]
        atlas=Image.new('RGBA',(CELL*8,CELL*4))
        production=[]
        bboxes=[]
        for r in range(4):
            production.append([])
            for direction,col in enumerate(COLS[name]):
                comp=rows[r][col]
                pose_im=im
                pose_filename=filename
                ref_rows=rows
                if name=='fox' and direction==1:
                    comp=repaired_rows[r][col]
                    pose_im=repaired_im
                    pose_filename=FOX_SE_REPAIR
                    ref_rows=repaired_rows
                # Native crop retains edge fringe. No alpha threshold applied to output.
                x0,y0,x1,y1=comp['bbox']
                crop_box=(max(0,x0-3),max(0,y0-3),min(im.width,x1+3),min(im.height,y1+3))
                cropped=pose_im.crop(crop_box)
                # Stable upper-body centroid for horizontal registration, avoiding tail/paw jitter.
                ca=np.asarray(cropped)[:,:,3].astype(float)/255
                upper=ca.copy();upper[int(ca.shape[0]*.66):]=0
                cx=float((upper.sum(axis=0)*np.arange(upper.shape[1])).sum()/upper.sum())
                ref=ref_rows[0][col]['bbox']
                # Register top of head/back, not changing body height by scaling.
                # The tiny bob remains deliberate; rabbit's airborne key lifts whole silhouette.
                bob=([0,-2,-5,-1] if name=='rabbit' else [0,-1,0,-1])[r]
                paste_x=int(round(ANCHOR[0]-cx))
                ref_height=ref[3]-ref[1]
                paste_y=ANCHOR[1]-ref_height-3+bob
                assert paste_x>=0 and paste_y>=0,(name,r,direction,paste_x,paste_y)
                assert paste_x+cropped.width<CELL and paste_y+cropped.height<CELL,(name,r,direction,cropped.size)
                origin=(direction*CELL+paste_x,r*CELL+paste_y)
                atlas.paste(cropped,origin)
                # Verify preserved exact source RGBA, including fringe alpha.
                check=np.asarray(atlas.crop((origin[0],origin[1],origin[0]+cropped.width,origin[1]+cropped.height)))
                assert np.array_equal(check,np.asarray(cropped))
                record={'source_rect':[direction*CELL,r*CELL,CELL,CELL],
                  'anchor':list(ANCHOR),'native_source_crop':list(crop_box),
                  'native_source_file':pose_filename,
                  'native_source_column':col,'native_source_row':r,
                  'native_paste':[paste_x,paste_y],
                  'paint_bounds':[paste_x+3,paste_y+3,paste_x+3+x1-x0,paste_y+3+y1-y0]}
                production[r].append(record)
                bboxes.append(comp['bbox'])
        atlas_path=DEST/f'wildlife-{name}.png';atlas.save(atlas_path)
        shutil.copy2(atlas_path,ARCHIVE/'production'/atlas_path.name)
        # poses[direction][frame] for runtime, source_rect also matches regular grid.
        poses=[[production[r][di] for r in range(4)] for di in range(8)]
        ref_h=int(round(np.median([rr['bbox'][3]-rr['bbox'][1] for rr in rows[0]])))
        species={'path':f'res://assets/wildlife-{name}.png','cell':[CELL,CELL],
           'anchor':list(ANCHOR),'angles':[0,45,90,135,180,225,270,315],
           'frames':4,'idle_frame':0,'world_height':HEIGHT[name],
           'reference_height_px':ref_h,'stride_world':STRIDE[name],
           'poses':poses,'native_source_dimensions':list(im.size),
           'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),
           'production_sha256':hashlib.sha256(atlas_path.read_bytes()).hexdigest()}
        data['species'][name]=species
        report[name]={'components':len(cc),'native_source_size':list(im.size),'reference_height_px':ref_h,
           'all_source_pixels_preserved':True,'direction_source_columns':COLS[name],
           'all_32_native_crop_hashes_exact':True,'transparent_padding':True,
           'pose_paint_bounds':[[p['paint_bounds'] for p in dr] for dr in poses]}
        # Native detail samples: only composition/padding, never paint generation.
        cell=atlas.crop((CELL*1,0,CELL*2,CELL))
        sheet.paste((211,220,175),(i*320+10,72,i*320+310,425))
        preview=cell.crop((42,90,342,382))
        sheet.paste(preview,(i*320+10,92),preview)
        d.text((i*320+32,438),name.upper(),font=font,fill=(51,69,55))
        sd.text((18,i*260+10),name.upper()+' / EAST',font=font,fill=(244,235,208))
        for r in range(4):
            pose=atlas.crop((2*CELL,r*CELL,3*CELL,(r+1)*CELL))
            # QA filmstrip at native pixels, cropped into300x220 region.
            sample=pose.crop((36,105,348,325))
            strip.paste(sample,(r*390+60,i*260+38),sample)
        gif_species.append(atlas)
    (DEST/'animal_atlas.json').write_text(json.dumps(data,indent=2)+'\n')
    shutil.copy2(DEST/'animal_atlas.json',ARCHIVE/'production/animal_atlas.json')
    (ART/'native-registration-report.json').write_text(json.dumps(report,indent=2)+'\n')
    sheet.save(ART/'five-animals-preview.png')
    strip.save(ART/'walking-keys-native.png')
    # Honest animated filmstrip for gait inspection. Native RGBA poses, constant anchors.
    animation=[]
    for frame in [0,1,2,3]:
        board=Image.new('RGBA',(1600,490),(117,151,105,255));draw=ImageDraw.Draw(board)
        for i,(name,atlas) in enumerate(zip(SOURCE,gif_species)):
            pose=atlas.crop((2*CELL,frame*CELL,3*CELL,(frame+1)*CELL))
            # 320px panel; all real paint within these x bounds.
            pose=pose.crop((32,0,352,CELL))
            board.alpha_composite(pose,(i*320,25))
            draw.text((i*320+32,428),name.upper(),font=font,fill=(244,235,208))
        animation.append(board.convert('RGB'))
    animation[0].save(ART/'five-animals-walk.gif',save_all=True,append_images=animation[1:],duration=150,loop=0,disposal=2)
    print(json.dumps({k:{'reference_height_px':v['reference_height_px'],'source_cols':COLS[k]} for k,v in data['species'].items()}))
if __name__=='__main__':main()

