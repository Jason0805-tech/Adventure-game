"""Create an offline single HTML file from the verified web build."""
from pathlib import Path
import base64,gzip,json,re
ROOT=Path(__file__).resolve().parent
GAME=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.3/review-fixes/candidate-game')
DIST=ROOT/'dist'
payload=json.loads((DIST/'payload.json').read_text())
def uri(path,mime):return 'data:'+mime+';base64,'+base64.b64encode(path.read_bytes()).decode()
html=(DIST/'index.html').read_text().replace('src="cover.png"','src="'+uri(DIST/'cover.png','image/png')+'"').replace('src="icon.png"','src="'+uri(DIST/'icon.png','image/png')+'"')
html=html.replace('href="app-icon-rowan.png"','href="'+uri(DIST/'icon.png','image/png')+'"')
html=html.replace("url('meadow.jpg')","url('"+uri(DIST/'meadow.jpg','image/jpeg')+"')")
html=html.replace('<link rel="manifest" href="manifest.webmanifest">','')
html=html.replace('First load is about 107 MB.','Offline HTML edition · no download after opening.')
html=html.replace('Menus pause the world. Refreshing starts a new run.','Menus pause the world. Refreshing starts a new run. iPhone file previews may require a web server.')
tags=[]
for name in ['game.wasm','game.pck']:
    compressed=gzip.compress((GAME/'web'/name).read_bytes(),compresslevel=6,mtime=0)
    tags.append('<script type="application/octet-stream" id="embedded-'+name+'">'+base64.b64encode(compressed).decode()+'</script>')
worklets={name:(DIST/name.replace('godot.','game.')).read_text() for name in ['godot.audio.worklet.js','godot.audio.position.worklet.js']}
prelude='''<script>
window.FOREST_PAYLOAD='''+json.dumps(payload,separators=(',',':'))+''';
window.FOREST_WORKLETS={};
for(const [name,source] of Object.entries('''+json.dumps(worklets)+'''))window.FOREST_WORKLETS[name]=URL.createObjectURL(new Blob([source],{type:'application/javascript'}));
window.readForestEmbedded=async function(name){
 if(typeof DecompressionStream==='undefined')throw new Error('This HTML needs a browser with gzip decompression. Try current Safari or Chrome.');
 const node=document.getElementById('embedded-'+name);let encoded=node.textContent.trim();node.remove();
 const padding=encoded.endsWith('==')?2:encoded.endsWith('=')?1:0;
 const zipped=new Uint8Array(encoded.length/4*3-padding);let offset=0;
 for(let i=0;i<encoded.length;i+=1048576){const text=atob(encoded.slice(i,i+1048576));for(let j=0;j<text.length;j++)zipped[offset++]=text.charCodeAt(j)}
 encoded='';
 return new Response(new Blob([zipped]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer();
};
</script>'''
engine=(DIST/'game.js').read_text()
for name in ['audio.worklet.js','audio.position.worklet.js']:
    old='return `${loadPath}.'+name+'`;'
    new='return window.FOREST_WORKLETS["godot.'+name+'"] || `${loadPath}.'+name+'`;'
    assert old in engine
    engine=engine.replace(old,new)
loader=(DIST/'loader.js').read_text().replace("new Engine({canvas,","new Engine({persistentPaths:[],canvas,")
loader=loader.replace("const response=await fetch('payload.json');if(!response.ok)throw new Error('Game download is unavailable.');\n     const payload=await response.json();",'const payload=window.FOREST_PAYLOAD;')
old='for(const file of payload.files)buffers.set(new URL(file.name,location.href).href,await loadBinary(file,finished,total));'
new='''for(const file of payload.files){status.textContent='Unpacking '+file.name+'…';buffers.set(new URL(file.name,location.href).href,await window.readForestEmbedded(file.name));finished.value+=file.bytes;progress.value=finished.value/total;}'''
assert old in loader
loader=loader.replace(old,new)
html=html.replace('<script src="game.js"></script><script src="loader.js"></script>', ''.join(tags)+prelude+'<script>'+engine.replace('</script','<\\/script')+'</script><script>'+loader.replace('</script','<\\/script')+'</script>')
target=GAME/'Forest Wanderer 0.1.6.3.html'
target.write_text(html)
print(json.dumps({'file':str(target),'bytes':target.stat().st_size,'MiB':round(target.stat().st_size/1024/1024,1),'external_script_tags':len(re.findall(r'<script[^>]+src=',html))},indent=2))
