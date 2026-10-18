// Executes the official exported4.7.2 Engine/Preloader/Config JS unchanged.
// Only the native Godot runtime is stubbed; it consumes a real minimal WASM.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const game='/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/output/0.1.6 series/adventure game 0.1.6.3/web/game.js';
const loader='/Users/jasonsmacair/Documents/Codex/2026-10-10/gao/sites/forest-wanderer/loader.js';
const source=fs.readFileSync(game,'utf8');const api=source.slice(source.indexOf('const Features ='));
assert.ok(api.startsWith('const Features ='),'Official exported Engine API suffix found');
let checks=0;function check(ok,note){checks++;assert.ok(ok,note)}
const records={},calls=[],events={};
class Node{constructor(){this.hidden=false;this.disabled=false;this.value=0;this.textContent='';this.classList={add:()=>records.welcomeHidden=true,remove:()=>records.welcomeHidden=false}}addEventListener(name,fn){this[name]=fn}focus(){records.focus=true}}
class Canvas extends Node{getBoundingClientRect(){return{width:844,height:390,left:47,top:0}}getContext(){return{MAX_TEXTURE_SIZE:3379,getParameter:()=>16384,getExtension:()=>({loseContext(){}})}}}
const nodes=Object.fromEntries(['start','progress','status','error','welcome','wechat','stage'].map(id=>[id,new Node()]));nodes.canvas=new Canvas();
const wasm=new Uint8Array([0,97,115,109,1,0,0,0]),pack=new Uint8Array([71,68,80,67,42,0,0,0]);
const payload={files:[{name:'game.wasm',bytes:wasm.length,parts:[{url:'data/wasm.bin',bytes:wasm.length}]},{name:'game.pck',bytes:pack.length,parts:[{url:'data/pack.bin',bytes:pack.length}]}],sizes:{'game.wasm':8,'game.pck':8}};
const nativeFetch=async(input)=>{const url=typeof input==='string'?input:input.url||String(input);calls.push(url);if(url==='payload.json')return new Response(JSON.stringify(payload));if(url==='data/wasm.bin')return new Response(wasm);if(url==='data/pack.bin')return new Response(pack);if(url.endsWith('.audio.worklet.js'))return new Response('/* worklet */');throw new Error('Unexpected missing unsplit network URL '+url)};
const sandbox={devicePixelRatio:2,ResizeObserver:class{constructor(callback){records.resizeCallback=callback}observe(target){records.observed=target}},console,URL,URLSearchParams,Response,Request,ReadableStream,Uint8Array,ArrayBuffer,WebAssembly,Promise,Map,HTMLCanvasElement:Canvas,fetch:nativeFetch,navigator:{userAgent:'iPhone Safari',maxTouchPoints:5,languages:['en-US']},location:{href:'https://forest.example/play/',search:'',reload(){}},matchMedia:()=>({matches:true}),innerWidth:1000,innerHeight:600,document:{hidden:false,hasFocus:()=>true,body:{classList:{toggle:(name,value)=>records.touchClass=value}},getElementById:id=>nodes[id],createElement:()=>new Canvas(),getElementsByTagName:()=>[nodes.canvas],addEventListener:(name,fn)=>events[name]=fn},addEventListener:(name,fn)=>events[name]=fn,visualViewport:{addEventListener(){}},requestAnimationFrame:fn=>setTimeout(fn,0),setTimeout};
sandbox.window=sandbox;
sandbox.Godot=async moduleConfig=>{
 records.moduleConfig=moduleConfig;
 // Exercise official Response.clone + tracked ReadableStream + streaming MIME.
 await new Promise(resolve=>moduleConfig.instantiateWasm({},(instance)=>{check(instance instanceof WebAssembly.Instance,'Official instantiateWasm consumed valid streaming response');resolve()}));
 return{initFS:async paths=>{records.persistentPaths=paths},copyToFS:(path,buffer)=>{records.fs={path,buffer}},initConfig:config=>{records.nativeConfig=config},callMain:args=>{records.args=args;moduleConfig.print('GAME_READY 0.1.6.3')},request_quit:()=>records.nativeConfig.onExit(0)};
};
(async()=>{
 const context=vm.createContext(sandbox);vm.runInContext(api,context,{filename:'official4.7.2-engine-api.js'});vm.runInContext(fs.readFileSync(loader,'utf8'),context,{filename:loader});
 await nodes.start.click();
 check(!nodes.error.textContent,'No loader error');
 check(sandbox.forestReady&&records.welcomeHidden&&records.focus,'GAME_READY from runtime exposes focused game');
 check(records.fs.path==='game.pck'&&Buffer.from(records.fs.buffer).equals(Buffer.from(pack)),'Official Preloader copied exact original main pack');
 check(records.args.join(' ')==='--main-pack game.pck','Official startGame generated correct main-pack argument');
 check(records.moduleConfig.locateFile('godot.audio.worklet.js')==='game.audio.worklet.js','Official worklet file mapping');
 check(records.moduleConfig.locateFile('godot.audio.position.worklet.js')==='game.audio.position.worklet.js','Official positional worklet mapping');
 check(records.moduleConfig.locateFile('godot.web.template_release.wasm32.nothreads.wasm')==='game.wasm','Official template WASM alias maps to game.wasm');
 check(records.nativeConfig.canvas===nodes.canvas&&records.nativeConfig.canvasResizePolicy===0,'Official API accepted canvas and resize settings');
 check(nodes.canvas.width===1688&&nodes.canvas.height===780&&records.observed===nodes.stage,'Official policy0 preserves external safe-area/DPR sizing');
 check(records.nativeConfig.focusCanvas===true&&records.nativeConfig.virtualKeyboard===false,'Official API accepted focus and VK configuration');
 check(!calls.includes('game.wasm')&&!calls.includes('game.pck'),'Both stock fetches consumed assembled buffers');
 await sandbox.fetch('game.audio.worklet.js');check(calls.at(-1)==='game.audio.worklet.js','Native fetch restored after real Engine API startup');
 sandbox.forestEngine.requestQuit();check(!records.welcomeHidden,'Official requestQuit/onExit returns to welcome');
 console.log('ACTUAL_EXPORTED_ENGINE_API_PASS',checks,'native_runtime_stubbed=true minimal_wasm_compiled=true');
})().catch(error=>{console.error(error);process.exitCode=1});
