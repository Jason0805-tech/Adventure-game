import { t } from '/assets/site.js';
const canvas=document.getElementById('canvas'),start=document.getElementById('start'),status=document.getElementById('status'),progress=document.getElementById('progress'),error=document.getElementById('error'),stage=document.getElementById('stage');
let starting=false,needsReload=false,readyTimer;
const touch=matchMedia('(pointer:coarse)').matches||navigator.maxTouchPoints>0||new URLSearchParams(location.search).get('touch')==='1';
document.body.classList.toggle('touch',touch);
if(/MicroMessenger/i.test(navigator.userAgent))document.getElementById('wechat').hidden=false;
const release=()=>{if(typeof window.forestGameState==='function')window.forestGameState(true)};
const resize=()=>{
  if(stage.hidden)return;
  const rect=canvas.getBoundingClientRect(),ratio=window.devicePixelRatio||1;
  const width=Math.max(1,Math.round(rect.width*ratio)),height=Math.max(1,Math.round(rect.height*ratio));
  if(canvas.width!==width)canvas.width=width;if(canvas.height!==height)canvas.height=height;
  if(typeof window.forestGameState==='function')window.forestGameState((touch&&rect.height>rect.width)||document.hidden||!document.hasFocus());
};
// One owner for focus / orientation suspension, inherited from the verified
// 0.1.6.4 shell. Keep native pixel density and the safe-area-aware stage.
document.addEventListener('visibilitychange',resize);window.addEventListener('blur',release);window.addEventListener('focus',resize);
window.addEventListener('pagehide',release);
window.addEventListener('pageshow',event=>{if(event.persisted&&starting)location.reload();});
window.addEventListener('resize',resize);window.visualViewport?.addEventListener('resize',resize);new ResizeObserver(resize).observe(stage);
for(const name of ['contextmenu','gesturestart','gesturechange','gestureend'])canvas.addEventListener(name,event=>event.preventDefault(),{passive:false});
window.forestReady=false;
function ready(){
  if(window.forestReady)return;window.forestReady=true;clearTimeout(readyTimer);
  document.body.classList.remove('is-starting');document.body.classList.add('is-playing');
  canvas.focus();resize();
}
function loadEngineScript(){return new Promise((resolve,reject)=>{
  const script=document.createElement('script');script.src='game.js';script.onload=resolve;script.onerror=()=>reject(new Error(t('unavailable')));document.head.append(script);
});}
async function loadBinary(spec,finished,total){
  const output=new Uint8Array(spec.bytes);let offset=0;
  for(const part of spec.parts){
    const response=await fetch(part.url,{cache:'default'});if(!response.ok)throw new Error(`${t('unavailable')} (${response.status})`);
    if(response.body){
      const reader=response.body.getReader();let size=0;
      for(;;){const {done,value}=await reader.read();if(done)break;if(size+value.length>part.bytes)throw new Error(t('incomplete'));output.set(value,offset+size);size+=value.length;finished.value+=value.length;progress.value=finished.value/total;status.textContent=`${t('loading')} ${Math.round(progress.value*100)}%`;}
      if(size!==part.bytes)throw new Error(t('incomplete'));offset+=size;
    }else{
      const bytes=new Uint8Array(await response.arrayBuffer());if(bytes.byteLength!==part.bytes)throw new Error(t('incomplete'));
      output.set(bytes,offset);offset+=bytes.length;finished.value+=bytes.length;progress.value=finished.value/total;status.textContent=`${t('loading')} ${Math.round(progress.value*100)}%`;
    }
  }
  if(offset!==spec.bytes)throw new Error(t('incomplete'));return output.buffer;
}
start.addEventListener('click',async()=>{
  if(needsReload){location.reload();return;}if(starting)return;
  starting=true;start.disabled=true;error.textContent='';progress.hidden=false;status.textContent=t('loading');
  document.querySelectorAll('[data-language]').forEach(button=>button.disabled=true);
  stage.hidden=false;document.body.classList.add('is-starting');resize();
  let nativeFetch;
  try{
    const probe=document.createElement('canvas'),gl=probe.getContext('webgl2');
    if(!gl)throw new Error(t('webgl'));if(gl.getParameter(gl.MAX_TEXTURE_SIZE)<8192)throw new Error(t('texture'));gl.getExtension('WEBGL_lose_context')?.loseContext();
    await loadEngineScript();
    const response=await fetch('payload.json');if(!response.ok)throw new Error(t('unavailable'));const payload=await response.json();
    const total=payload.files.reduce((sum,file)=>sum+file.bytes,0),finished={value:0},buffers=new Map();
    for(const file of payload.files)buffers.set(new URL(file.name,location.href).href,await loadBinary(file,finished,total));
    nativeFetch=window.fetch.bind(window);
    window.fetch=(input,init)=>{
      const url=new URL(typeof input==='string'?input:input.url||String(input),location.href).href;
      if(buffers.has(url)){const buffer=buffers.get(url);buffers.delete(url);return Promise.resolve(new Response(buffer,{headers:{'Content-Type':url.endsWith('.wasm')?'application/wasm':'application/octet-stream','Content-Length':String(buffer.byteLength)}}));}
      return nativeFetch(input,init);
    };
    status.textContent=t('starting');resize();
    const engine=new window.Engine({canvas,executable:'game',mainPack:'game.pck',fileSizes:payload.sizes,canvasResizePolicy:0,focusCanvas:true,experimentalVK:false,
      onPrint:(...args)=>{console.log(...args);if(args.join(' ').includes('GAME_READY'))ready();},onPrintError:(...args)=>console.error(...args),
      onExit:()=>{release();document.body.classList.remove('is-playing','is-starting');stage.hidden=true;status.textContent=t('closed');start.textContent=t('reload');start.disabled=false;needsReload=true;}
    });
    window.forestEngine=engine;await engine.startGame();window.fetch=nativeFetch;
    if(!window.forestReady)readyTimer=setTimeout(()=>{if(!window.forestReady){error.textContent=t('unavailable');status.textContent=t('failed');needsReload=true;start.textContent=t('retry');start.disabled=false;}},60000);
  }catch(exception){
    if(nativeFetch)window.fetch=nativeFetch;clearTimeout(readyTimer);
    document.body.classList.remove('is-starting');stage.hidden=true;error.textContent=exception.message||String(exception);status.textContent=t('failed');
    start.textContent=t('retry');start.disabled=false;needsReload=true;document.querySelectorAll('[data-language]').forEach(button=>button.disabled=false);
  }
});
