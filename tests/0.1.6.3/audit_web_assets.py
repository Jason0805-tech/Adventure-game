"""Inventory original assets; no source images or runtime files are changed."""
from pathlib import Path
import hashlib,json
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
RELEASE=ROOT/'output/0.1.6 series/adventure game 0.1.6.3'
OUT=Path(__file__).resolve().parent
manifest={}
for p in sorted((RELEASE/'assets').iterdir()):
    if p.suffix.lower()not in ['.png','.json','.bin']:continue
    entry={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
    if p.suffix.lower()=='.png':
        with Image.open(p)as im:entry['width'],entry['height']=im.size
        entry['rgba8_bytes']=entry['width']*entry['height']*4
        entry['rgba8_mip_bytes_estimate']=round(entry['rgba8_bytes']*4/3)
    manifest['res://assets/'+p.name]=entry
p=RELEASE/'collision_profiles.json'
manifest['res://collision_profiles.json']={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
(OUT/'packaged_asset_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
pngs=[v for k,v in manifest.items()if k.endswith('.png')]
summary={'raw_png_files':len(pngs),'all_png_rgba8_mib':sum(v['rgba8_bytes']for v in pngs)/1048576,'all_source_file_mib':sum(v['bytes']for v in manifest.values())/1048576,'max_dimension':max(max(v['width'],v['height'])for v in pngs),'larger_than_4096':[k for k,v in manifest.items()if max(v.get('width',0),v.get('height',0))>4096]}
(OUT/'web_asset_inventory.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
