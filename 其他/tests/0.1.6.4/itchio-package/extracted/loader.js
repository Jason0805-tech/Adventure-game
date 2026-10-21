'use strict';
(() => {
 const canvas=document.getElementById('canvas'), start=document.getElementById('start'), status=document.getElementById('status'), progress=document.getElementById('progress'), error=document.getElementById('error');
 let starting=false;
 const touch=matchMedia('(pointer:coarse)').matches || navigator.maxTouchPoints>0 || new URLSearchParams(location.search).get('touch')==='1';
 document.body.classList.toggle('touch',touch);
 if (/MicroMessenger/i.test(navigator.userAgent)) document.getElementById('wechat').hidden=false;
 for (const event of ['contextmenu','gesturestart','gesturechange','gestureend']) document.addEventListener(event,e=>e.preventDefault(),{passive:false});
 const release=()=>{if(typeof window.forestGameState==='function')window.forestGameState(true)};
 document.addEventListener('visibilitychange',()=>resize());
 window.addEventListener('blur',release);
 window.addEventListener('focus',()=>resize());
 // Policy 0 lets our padded stage own sizing. Godot's full-window policy
 // positions the canvas at (0,0), which bypasses the iPhone safe-area padding.
 const resize=()=>{
   const rect=canvas.getBoundingClientRect(),ratio=window.devicePixelRatio||1;
   const width=Math.max(1,Math.round(rect.width*ratio)),height=Math.max(1,Math.round(rect.height*ratio));
   if(canvas.width!==width)canvas.width=width;
   if(canvas.height!==height)canvas.height=height;
   if(typeof window.forestGameState==='function')window.forestGameState((touch && rect.height>rect.width) || document.hidden || !document.hasFocus());
 };
 new ResizeObserver(resize).observe(document.getElementById('stage'));resize();
 window.addEventListener('resize',resize);window.visualViewport?.addEventListener('resize',resize);
 window.forestReady=false;
 function ready(){window.forestReady=true;document.getElementById('welcome').classList.add('hidden');canvas.focus();resize()}
 async function loadBinary(spec,finished,total){
   const output=new Uint8Array(spec.bytes);let offset=0;
   for(const part of spec.parts){
     const response=await fetch(part.url,{cache:'default'});
     if(!response.ok)throw new Error('Download failed ('+response.status+'). Please try again.');
     const bytes=new Uint8Array(await response.arrayBuffer());
     if(bytes.byteLength!==part.bytes)throw new Error('Incomplete game download. Please reload.');
     output.set(bytes,offset);offset+=bytes.length;finished.value+=bytes.length;
     progress.value=finished.value/total;status.textContent='Gathering the forest… '+Math.round(progress.value*100)+'%';
   }
   if(offset!==spec.bytes)throw new Error('Game data size mismatch.');
   return output.buffer;
 }
 start.addEventListener('click',async()=>{
   if(starting)return;starting=true;start.disabled=true;error.textContent='';progress.hidden=false;
   let nativeFetch;
   try{
     const probe=document.createElement('canvas');const gl=probe.getContext('webgl2');
     if(!gl)throw new Error('This game needs WebGL 2. Try opening the link in Safari.');
     if(gl.getParameter(gl.MAX_TEXTURE_SIZE)<8192)throw new Error('This device cannot load the full-quality character artwork. Try a newer device.');
     gl.getExtension('WEBGL_lose_context')?.loseContext();
     const response=await fetch('payload.json');if(!response.ok)throw new Error('Game download is unavailable.');
     const payload=await response.json();const total=payload.files.reduce((n,f)=>n+f.bytes,0),finished={value:0};
     const buffers=new Map();
     for(const file of payload.files)buffers.set(new URL(file.name,location.href).href,await loadBinary(file,finished,total));
     // Godot's stock loader requests these two exact URLs. Serve the assembled
     // original bytes as Responses so the supported Engine API stays unchanged.
     nativeFetch=window.fetch.bind(window);
     window.fetch=(input,init)=>{
       const url=new URL(typeof input==='string'?input:input.url||String(input),location.href).href;
       if(buffers.has(url)){
         const buffer=buffers.get(url);buffers.delete(url);
         return Promise.resolve(new Response(buffer,{headers:{'Content-Type':url.endsWith('.wasm')?'application/wasm':'application/octet-stream','Content-Length':String(buffer.byteLength)}}));
       }
       return nativeFetch(input,init);
     };
     status.textContent='Painting the forest…';
     resize();
     const engine=new Engine({canvas,executable:'game',mainPack:'game.pck',fileSizes:payload.sizes,canvasResizePolicy:0,focusCanvas:true,experimentalVK:false,onPrint:(...args)=>{console.log(...args);if(args.join(' ').includes('GAME_READY'))ready()},onPrintError:(...args)=>console.error(...args),onExit:()=>{release();document.getElementById('welcome').classList.remove('hidden');status.textContent='The game has closed. Reload to start a new run.';start.textContent='Reload game';start.disabled=false;start.onclick=()=>location.reload()}});
     window.forestEngine=engine;
     await engine.startGame();
     window.fetch=nativeFetch;
     if(!window.forestReady)ready();
   }catch(e){
     if(nativeFetch)window.fetch=nativeFetch;
     error.textContent=e.message||String(e);status.textContent='The forest could not open.';
     start.textContent='Reload and try again';start.disabled=false;start.onclick=()=>location.reload();
   }
 });
})();
