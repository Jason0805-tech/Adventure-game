import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import path from 'node:path';
const root=path.resolve('tests/personal-website/0.1.0/site/dist');
const {site,copy}=await import('file://'+root+'/assets/content.js');
const results=[];const check=(name,fn)=>{fn();results.push({name,result:'pass'});};
check('Bilingual dictionary keys match',()=>assert.deepEqual(Object.keys(copy.zh).sort(),Object.keys(copy.en).sort()));
check('Contact details remain unpublished until supplied',()=>assert.deepEqual(Object.values(site.contacts),[null,null,null,null]));
for(const relative of ['index.html','games/forest-wanderer/index.html']){
 const html=fs.readFileSync(path.join(root,relative),'utf8');
 check(relative+' translation keys exist',()=>{for(const [,key] of html.matchAll(/data-i18n="([^"]+)"/g))assert.ok(key in copy.zh,key);});
 check(relative+' local references resolve',()=>{for(const [,url] of html.matchAll(/(?:src|href)="([^"]+)"/g)){if(/^(?:https?:|mailto:|tel:|#)/.test(url))continue;let file=path.resolve(path.dirname(path.join(root,relative)),url.startsWith('/')?root+url.split('#')[0]:url.split('#')[0]);if(fs.existsSync(file)&&fs.statSync(file).isDirectory())file=path.join(file,'index.html');assert.ok(fs.existsSync(file),file);}});
 check(relative+' no duplicate IDs',()=>{const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(x=>x[1]);assert.equal(new Set(ids).size,ids.length);});
 check(relative+' does not eagerly include engine',()=>assert.ok(!/<script[^>]+src="[^\"]*game\.js/.test(html)));
}
const js=fs.readFileSync(root+'/assets/site.js','utf8');
const transition=js.slice(js.indexOf("document.addEventListener('click'"));
for(const reduced of [false,true]){
 const callbacks={},classes=new Set();let prevented=false,delay=null,assigned=null;
 const document={addEventListener:(n,cb)=>callbacks[n]=cb,documentElement:{classList:{contains:v=>classes.has(v),add:v=>classes.add(v),remove:v=>classes.delete(v)}}};
 const window={addEventListener:(n,cb)=>callbacks[n]=cb};
 const location={origin:'https://test.example',assign:v=>assigned=v};
 vm.runInNewContext(transition,{document,window,location,URL,matchMedia:()=>({matches:reduced}),setTimeout:(cb,ms)=>{delay=ms;cb();}});
 const link={href:'https://test.example/games/forest-wanderer/',target:''};
 callbacks.click({target:{closest:()=>link},button:0,preventDefault:()=>prevented=true});
 check('Reduced-motion '+reduced+' transition contract',()=>{assert.equal(prevented,!reduced);assert.equal(delay,reduced?null:350);assert.equal(assigned,reduced?null:link.href);});
 callbacks.pageshow();check('Back navigation clears transition '+reduced,()=>assert.equal(classes.size,0));
}
fs.writeFileSync('tests/personal-website/0.1.0/static-check-results.json',JSON.stringify({kind:'Source and JavaScript contract checks; not browser/device tests',checks:results},null,2));
console.log(JSON.stringify({passed:results.length}));
