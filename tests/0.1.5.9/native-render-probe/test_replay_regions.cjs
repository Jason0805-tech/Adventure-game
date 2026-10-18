const fs=require('fs'),path=require('path'),assert=require('assert');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {coalesceTextureRuns,prepareTextureRasters,snapshotSvg}=require('../render_captures.cjs');
const folder=__dirname;
async function raster(data){await prepareTextureRasters(data);return sharp(Buffer.from(snapshotSvg(data))).ensureAlpha().raw().toBuffer();}
(async()=>{
 const pixels=Buffer.alloc(16*16*4);
 for(let y=0;y<16;y++)for(let x=0;x<16;x++){
  const i=(y*16+x)*4;pixels[i]=80+x*9;pixels[i+1]=100+y*8;pixels[i+2]=160;pixels[i+3]=80+x*10;
 }
 const file=path.join(folder,'seam-test-texture.png');
 await sharp(pixels,{raw:{width:16,height:16,channels:4}}).png().toFile(file);
 const texture={path:file,width:16,height:16};
 const backdrop={kind:'rect',rect:[0,0,80,80],color:[0.13,0.35,0.19,1],filled:true,transform:[0,0,0,1,1]};
 const offscreen={kind:'rect',rect:[100,100,2,2],color:[1,0,0,1],filled:true,transform:[0,0,0,1,1]};
 const transforms=[[8.37,7.19,0,1,1],[56.37,7.19,0,-1,1],[40.37,7.19,0.31,1,1]];
 const results=[];
 for(const transform of transforms){
  const scale=2.173;
  const make=(left,width)=>({kind:'texture',texture,source:[left,0,width,16],rect:[left*scale,0,width*scale,16*scale],color:[0.86,0.97,0.88,0.73],transform});
  const striped=[];
  for(let x=0;x<16;x++)striped.push(make(x,1),offscreen);
  const original=await raster({width:80,height:80,commands:[backdrop,make(0,16)]});
  const split=await raster({width:80,height:80,commands:[backdrop,...striped]});
  let differing=0,maxDelta=0;for(let i=0;i<original.length;i++){const d=Math.abs(original[i]-split[i]);if(d)differing++;maxDelta=Math.max(maxDelta,d);}
  assert.equal(differing,0,'Uninterrupted full texture and depth-interleaved bands must be pixel identical');
  results.push({transform,differing_bytes:differing,max_delta:maxDelta});
 }
 const make=(left,width)=>({kind:'texture',texture,source:[left,0,width,16],rect:[left*2,0,width*2,32],color:[1,1,1,0.5],transform:[0,0,0,1,1]});
 const middle={...offscreen,rect:[1,1,4,4]};
 const order=coalesceTextureRuns([make(0,4),make(4,4),middle,make(8,4),make(12,4)]);
 assert.equal(order.length,3);assert.equal(order[1],middle);
 assert.equal(order[0].replayCommandCount,2);assert.equal(order[2].replayCommandCount,2);
 assert.deepEqual(order[0].replaySpans,[[0,0,8,16]]);assert.deepEqual(order[2].replaySpans,[[8,0,8,16]]);
 const overlap=coalesceTextureRuns([make(0,8),make(4,8)]);assert.equal(overlap.length,2);
 const report={pixel_identity_cases:results,paint_order_preserved:true,only_consecutive_runs_coalesced:true,translucent_overlap_multiplicity_preserved:true,renderer:'software Canvas replay with bilinear full-texture sampling and pixel-center region coverage; not native GPU frames'};
 fs.writeFileSync(path.join(folder,'replay-region-tests.json'),JSON.stringify(report,null,2));
 console.log('REPLAY_REGION_TESTS_PASS',JSON.stringify(report));
})().catch(error=>{console.error(error);process.exitCode=1;});
