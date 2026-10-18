// Tests the actual shell loader with a DOM/Engine-contract fixture.
// This is not a browser or WebAssembly gameplay test.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const path='/Users/jasonsmacair/Documents/Codex/2026-10-10/gao/sites/forest-wanderer/loader.js';
const source=fs.readFileSync(path,'utf8');
let checks=0;
function check(ok,message){checks++;assert.ok(ok,message)}
async function scenario(mode){
 const events={},docEvents={},calls=[],released=[],records={};let bounds={width:844,height:390,left:47,top:0};
 const node=()=>({hidden:false,textContent:'',disabled:false,value:0,onclick:null,getBoundingClientRect:()=>bounds,classes:new Set(),addEventListener(type,fn){this[type]=fn},classList:{add(name){records.hidden=true},remove(name){records.hidden=false}},focus(){records.focus=true}});
 const nodes=Object.fromEntries(['canvas','start','status','progress','error','welcome','wechat','stage'].map(k=>[k,node()]));
 const wasm=new Uint8Array([0,97,115,109,1,0,0,0]),pack=new Uint8Array([71,68,80,67,1,2,3,4,5]);
 const files=[{name:'game.wasm',bytes:wasm.length,parts:[{url:'data/wasm.0.bin',bytes:4},{url:'data/wasm.1.bin',bytes:4}]},{name:'game.pck',bytes:pack.length,parts:[{url:'data/pck.0.bin',bytes:pack.length}]}];
 const native=async(input)=>{
  const p=typeof input==='string'?input:input.url||String(input);calls.push(p);
  if(p==='payload.json')return new Response(JSON.stringify({files,sizes:{'game.wasm':8,'game.pck':9}}),{headers:{'Content-Type':'application/json'}});
  if(p==='data/wasm.0.bin')return new Response(mode==='badchunk'?new Uint8Array([0]):wasm.slice(0,4));
  if(p==='data/wasm.1.bin')return new Response(wasm.slice(4));
  if(p==='data/pck.0.bin')return new Response(pack);
  if(p.endsWith('.audio.worklet.js'))return new Response('/* worklet fixture */');
  throw new Error('Unexpected real-network request: '+p);
 };
 const sandbox={devicePixelRatio:2,ResizeObserver:class{constructor(callback){records.resizeCallback=callback}observe(target){records.observed=target}},console:{log(){},error(){}},URL,URLSearchParams,Request,Response,Uint8Array,ArrayBuffer,Map,Promise,fetch:native,location:{href:'https://forest.example/play/',search:mode==='forcedtouch'?'?touch=1':'',reload(){records.reloaded=true}},navigator:{userAgent:'iPhone Safari',maxTouchPoints:mode==='forcedtouch'?0:5},matchMedia:()=>({matches:mode!=='forcedtouch'}),innerWidth:1000,innerHeight:600,document:{hidden:false,hasFocus:()=>records.pageFocused!==false,body:{classList:{toggle:(name,value)=>records.touchClass=value}},getElementById:id=>nodes[id],addEventListener:(e,f)=>docEvents[e]=f,createElement:()=>({getContext:()=>mode==='nogl'?null:{MAX_TEXTURE_SIZE:3379,getParameter:()=>mode==='smallgpu'?4096:16384,getExtension:()=>({loseContext(){records.contextReleased=true}})}})},addEventListener:(e,f)=>events[e]=f,visualViewport:{addEventListener(){}},forestGameState:flag=>released.push(flag)};
 sandbox.window=sandbox;
 sandbox.Engine=class{
  constructor(config){records.config=config}
  async startGame(){
   records.started=true;
   if(mode==='engineerror')throw new Error('Engine fixture startup failed');
   const wasmResponse=await sandbox.fetch('game.wasm');
   check(wasmResponse.headers.get('Content-Type')==='application/wasm','Assembled WASM has streaming MIME');
   check(Buffer.from(await wasmResponse.clone().arrayBuffer()).equals(Buffer.from(wasm)),'WASM clone reproduces exact bytes');
   check(Buffer.from(await wasmResponse.arrayBuffer()).equals(Buffer.from(wasm)),'WASM original Response remains consumable');
   const packResponse=await sandbox.fetch(new Request('https://forest.example/play/game.pck'));
   check(Buffer.from(await packResponse.arrayBuffer()).equals(Buffer.from(pack)),'Request object resolves exact assembled PCK bytes');
   const auxiliary=await sandbox.fetch(new URL('game.audio.worklet.js',sandbox.location.href));
   check((await auxiliary.text()).includes('worklet'),'Auxiliary URL passes through native fetch');
   records.config.onPrint('GAME_READY 0.1.6.3');
  }
 };
 vm.runInNewContext(source,sandbox,{filename:path});
 await nodes.start.click();
 if(mode==='ok'||mode==='forcedtouch'){
  check(records.started&&sandbox.forestReady&&records.hidden&&records.focus,'Successful start waits for engine and shows canvas');
  check(records.config.executable==='game'&&records.config.mainPack==='game.pck','Engine executable/mainPack names match payload');
  check(records.config.canvasResizePolicy===0&&records.config.focusCanvas===true&&records.config.experimentalVK===false,'Supported4.7.2 Engine config values');
  check(nodes.progress.value===1,'Original payload download progress reaches1');
  check(nodes.canvas.width===1688&&nodes.canvas.height===780,'Canvas backing size follows safe-area content rect times DPR');
  check(records.observed===nodes.stage,'ResizeObserver follows padded stage');
  check(records.touchClass===true,'Natural or forced touch mode toggles matching shell class');
  bounds={width:390,height:844,left:0,top:0};events.resize();check(nodes.canvas.width===780&&nodes.canvas.height===1688&&released.at(-1)===true,'Portrait resize updates native pixel backing and suspends input');
  bounds={width:844,height:390,left:47,top:0};events.resize();check(released.at(-1)===false,'Portrait to landscape restores browser state');
  sandbox.document.hidden=true;events.resize();check(released.at(-1)===true,'Landscape resize cannot resume hidden page');
  sandbox.document.hidden=false;records.pageFocused=false;events.resize();check(released.at(-1)===true,'Landscape resize cannot resume blurred page');
  records.pageFocused=true;events.resize();check(released.at(-1)===false,'Focused visible landscape resumes');
  records.pageFocused=false;events.blur();check(released.at(-1)===true,'Blur event suspends without requiring resize');
  records.pageFocused=true;events.focus();check(released.at(-1)===false,'Focus event resumes visible landscape without requiring resize');
  sandbox.document.hidden=true;docEvents.visibilitychange();check(released.at(-1)===true,'Visibility event suspends hidden page');
  events.focus();check(released.at(-1)===true,'Focus event cannot resume a still-hidden page');
  sandbox.document.hidden=false;docEvents.visibilitychange();check(released.at(-1)===false,'Visible event resumes focused landscape without requiring resize');
  bounds={width:390,height:844,left:0,top:0};events.focus();check(released.at(-1)===true,'Focus cannot override portrait suspension');
  bounds={width:844,height:390,left:47,top:0};events.resize();
  check(!calls.includes('game.wasm')&&!calls.some(v=>v.includes('game.pck')),'Stock engine requests do not hit missing unsplit network files');
  const before=calls.length;await sandbox.fetch('game.audio.worklet.js');check(calls.length===before+1,'Native fetch restored after successful start');
  sandbox.document.hidden=true;docEvents.visibilitychange();check(released.includes(true),'Hidden page releases active input');
  records.config.onExit(0);check(!records.hidden&&nodes.start.disabled===false,'Exit restores welcome and reload control');
 }else{
  check(!sandbox.forestReady&&nodes.error.textContent.length>0,'Failure remains visible and does not claim game ready');
  check(nodes.start.disabled===false&&typeof nodes.start.onclick==='function','Failure exposes reload retry');
  if(mode==='engineerror'){const before=calls.length;await sandbox.fetch('game.audio.worklet.js');check(calls.length===before+1,'Native fetch restored after engine error')}
 }
 return {mode,networkRequests:calls.length,engineStarted:!!records.started,error:nodes.error.textContent};
}
(async()=>{for(const mode of ['ok','forcedtouch','badchunk','nogl','smallgpu','engineerror'])console.log(JSON.stringify(await scenario(mode)));console.log('WEB_LOADER_CONTRACT_PASS',checks)})().catch(error=>{console.error(error);process.exitCode=1});
