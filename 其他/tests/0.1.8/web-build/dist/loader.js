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
 // Hosted CDNs (itch.io) can stall or drop a connection mid-download. Each
 // part streams with live progress, is aborted when no bytes arrive for
 // STALL_MS, and is retried with backoff. A few parts download in parallel.
 const STALL_MS=25000, ATTEMPTS=6, PARALLEL=3;
 const wait=ms=>new Promise(r=>setTimeout(r,ms));
 function show(finished,total,note){progress.value=finished.value/total;status.textContent=(note||'Gathering the forest… ')+Math.round(progress.value*100)+'%'}
 async function fetchPart(part,target,offset,finished,total){
   for(let attempt=1;attempt<=ATTEMPTS;attempt++){
     const controller=new AbortController();let timer=null,received=0;
     const arm=()=>{clearTimeout(timer);timer=setTimeout(()=>controller.abort(),STALL_MS)};
     try{
       arm();
       // The content hash in the URL means a new build can never mix with cached parts of an old one.
       const response=await fetch(part.url+'?h='+String(part.sha256||'').slice(0,16),{cache:'default',signal:controller.signal});
       if(!response.ok)throw new Error('Download failed ('+response.status+').');
       if(response.body&&response.body.getReader){
         const reader=response.body.getReader();
         for(;;){
           const {done,value}=await reader.read();
           if(done)break;
           arm();
           if(received+value.byteLength>part.bytes)throw new Error('Unexpected game data size.');
           target.set(value,offset+received);received+=value.byteLength;finished.value+=value.byteLength;show(finished,total);
         }
       }else{
         const all=new Uint8Array(await response.arrayBuffer());
         if(all.byteLength<=part.bytes)target.set(all,offset);
         received=all.byteLength;finished.value+=received;show(finished,total);
       }
       clearTimeout(timer);
       if(received!==part.bytes)throw new Error('Incomplete game download.');
       return;
     }catch(e){
       clearTimeout(timer);finished.value-=received;
       if(attempt===ATTEMPTS)throw new Error('The game download keeps failing. Please check your connection and reload.');
       show(finished,total,'Connection slow, retrying… ');
       await wait(1000*attempt);
     }
   }
 }
 async function loadBinaries(files,finished,total){
   // Parts are written straight into one buffer per file at their offsets,
   // so the assembled game is held in memory only once.
   const jobs=[],buffers=new Map();
   for(const file of files){
     const target=new Uint8Array(file.bytes);let offset=0;
     for(const part of file.parts){jobs.push({part,target,offset});offset+=part.bytes}
     if(offset!==file.bytes)throw new Error('Game data size mismatch.');
     buffers.set(new URL(file.name,location.href).href,target.buffer);
   }
   let next=0;
   const worker=async()=>{while(next<jobs.length){const job=jobs[next++];await fetchPart(job.part,job.target,job.offset,finished,total)}};
   await Promise.all(Array.from({length:Math.min(PARALLEL,jobs.length)},worker));
   return buffers;
 }
 start.addEventListener('click',async()=>{
   if(starting)return;starting=true;start.disabled=true;error.textContent='';progress.hidden=false;
   let nativeFetch;
   try{
     const probe=document.createElement('canvas');const gl=probe.getContext('webgl2');
     if(!gl)throw new Error('This game needs WebGL 2. Try opening the link in Safari.');
     if(gl.getParameter(gl.MAX_TEXTURE_SIZE)<8192)throw new Error('This device cannot load the full-quality character artwork. Try a newer device.');
     gl.getExtension('WEBGL_lose_context')?.loseContext();
     const response=await fetch('payload.json',{cache:'no-cache'});if(!response.ok)throw new Error('Game download is unavailable.');
     const payload=await response.json();const total=payload.files.reduce((n,f)=>n+f.bytes,0),finished={value:0};
     const buffers=await loadBinaries(payload.files,finished,total);
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
