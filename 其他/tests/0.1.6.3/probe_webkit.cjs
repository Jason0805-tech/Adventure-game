const fs=require('fs');
const path=require('path');
const {webkit,devices}=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright-core');
(async()=>{
 const result={method:'Patched Playwright WebKit26.5 on macOS with iPhone viewport/touch emulation. Not branded Safari or a physical iPhone.',checks:[],errors:[]};let browser;
 try{
  browser=await webkit.launch({headless:true,timeout:15000});
  result.browserVersion=browser.version();
  const context=await browser.newContext({...devices['iPhone 13 landscape']});
  const page=await context.newPage();
  await page.setContent('<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><canvas id="c"></canvas>');
  result.capabilities=await page.evaluate(()=>{const c=document.querySelector('#c');const gl=c.getContext('webgl2');const ext=gl&&gl.getExtension('WEBGL_debug_renderer_info');return {ua:navigator.userAgent,viewport:[innerWidth,innerHeight],screen:[screen.width,screen.height],dpr:devicePixelRatio,touch:navigator.maxTouchPoints,coarse:matchMedia('(pointer:coarse)').matches,webgl2:!!gl,renderer:gl&&ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):null,wasm:typeof WebAssembly==='object',visualViewport:visualViewport?{width:visualViewport.width,height:visualViewport.height,scale:visualViewport.scale}:null};});
  result.checks.push({name:'iPhone landscape viewport and touch',pass:result.capabilities.viewport[0]>result.capabilities.viewport[1]&&result.capabilities.touch>0});
  result.checks.push({name:'WebAssembly + WebGL2 available',pass:result.capabilities.wasm&&result.capabilities.webgl2});
  await context.close();
 }catch(error){result.errors.push(error.message);process.exitCode=1;}
 finally{if(browser)await browser.close();fs.writeFileSync(path.join(__dirname,'webkit-probe-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));}
})().catch(error=>{console.error(error);process.exitCode=1;});
