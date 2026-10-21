"""Verify split static-host payload reconstructs the unmodified web export."""
from pathlib import Path
import hashlib,json
ROOT=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
GAME=ROOT/'output/0.1.6 series/adventure game 0.1.6.3/web'
SITE=Path('/Users/jasonsmacair/Documents/Codex/2026-10-10/gao/sites/forest-wanderer/dist')
payload=json.loads((SITE/'payload.json').read_text());checks=0;failures=[]
def check(ok,note):
 global checks
 checks+=1
 if not ok:failures.append(note)
for file in payload['files']:
 full=hashlib.sha256();size=0
 for part in file['parts']:
  p=SITE/part['url'];data=p.read_bytes();full.update(data);size+=len(data)
  check(len(data)==part['bytes'],'Chunk length '+part['url'])
  check(hashlib.sha256(data).hexdigest()==part['sha256'],'Chunk hash '+part['url'])
  check(len(data)<=8*1024*1024,'Chunk hosting size '+part['url'])
 check(size==file['bytes']==payload['sizes'][file['name']],'Full payload length '+file['name'])
 check(full.hexdigest()==file['sha256']==hashlib.sha256((GAME/file['name']).read_bytes()).hexdigest(),'Original exported bytes reconstructed '+file['name'])
for name in ['game.js','game.audio.worklet.js','game.audio.position.worklet.js']:
 check((SITE/name).read_bytes()==(GAME/name).read_bytes(),'Unchanged official JS/auxiliary '+name)
html=(SITE/'index.html').read_text()
for text in ['src="game.js"','src="loader.js"','id="canvas"','id="start"','viewport-fit=cover']:
 check(text in html,'Shell includes '+text)
check('{{TOTAL_MB}}'not in html,'Shell download size rendered')
check((SITE/'loader.js').read_bytes()==(SITE.parent/'loader.js').read_bytes(),'Latest reviewed loader copied')
result={'checks':checks,'failures':failures,'payload_bytes':sum(f['bytes']for f in payload['files']),'payload_files':[f['name']for f in payload['files']]}
(ROOT/'tests/0.1.6.3/site-payload-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print('STATIC_SITE_PAYLOAD_AUDIT',json.dumps(result))
raise SystemExit(1 if failures else 0)
