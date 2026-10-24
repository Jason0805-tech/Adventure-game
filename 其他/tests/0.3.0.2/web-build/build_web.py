"""Package an unchanged Godot web export into small static-host assets."""
from pathlib import Path
import hashlib,json,shutil,subprocess
ROOT=Path(__file__).resolve().parent
# Local layout first, then the GitHub folder names.
GAME=next(p for p in [ROOT.parents[3]/'output/0.3.X/adventure game 0.3.0.2',ROOT.parents[3]/'output/0.3.0 series/adventure game 0.3.0.2'] if p.is_dir())
# Raw Godot export: in the release folder right after export, or archived in tests.
EXPORT=GAME/'web' if (GAME/'web'/'game.pck').is_file() else ROOT.parent/'raw-export'
OUT=ROOT/'dist'
shutil.rmtree(OUT,ignore_errors=True);OUT.mkdir()
(OUT/'data').mkdir(exist_ok=True)
payload={'version':'v0.3.0-alpha.2','files':[],'sizes':{}}
for name in ['game.wasm','game.pck']:
    raw=(EXPORT/name).read_bytes()
    record={'name':name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'parts':[]}
    for i,offset in enumerate(range(0,len(raw),8*1024*1024)):
        part=raw[offset:offset+8*1024*1024];url=f'data/{name}.{i:02}.bin'
        (OUT/url).write_bytes(part)
        record['parts'].append({'url':url,'bytes':len(part),'sha256':hashlib.sha256(part).hexdigest()})
    payload['files'].append(record);payload['sizes'][name]=len(raw)
(OUT/'payload.json').write_text(json.dumps(payload,indent=2)+'\n')
for path in EXPORT.glob('*.js'):
    shutil.copy2(path,OUT/path.name)
shutil.copy2(ROOT/'loader.js',OUT/'loader.js')
total=sum(f['bytes'] for f in payload['files'])
(OUT/'index.html').write_text((ROOT/'shell.html').read_text().replace('{{TOTAL_MB}}',str(round(total/1024/1024))))
icon=ROOT/'web-icon.png'
shutil.copy2(icon,OUT/'icon.png')
shutil.copy2(icon,OUT/'app-icon-rowan.png')
shutil.copy2(ROOT/'cover-original.png',OUT/'cover.png')
subprocess.run(['sips','-s','format','jpeg',str(GAME/'assets/meadow.png'),'--out',str(OUT/'meadow.jpg')],check=True,stdout=subprocess.DEVNULL)
(OUT/'manifest.webmanifest').write_text(json.dumps({'name':'Forest Wanderer','short_name':'Forest','start_url':'./','display':'standalone','orientation':'landscape','background_color':'#203d36','theme_color':'#294e45','icons':[{'src':'app-icon-rowan.png','sizes':'512x512','type':'image/png'}]},indent=2)+'\n')
for name in ['LICENSE.txt','ENGINE_LICENSES.txt']:shutil.copy2(GAME/name,OUT/name)
print(json.dumps({'payload_bytes':total,'largest_static_asset':max(f.stat().st_size for f in OUT.rglob('*') if f.is_file()),'files':len(list(OUT.rglob('*')))},indent=2))
