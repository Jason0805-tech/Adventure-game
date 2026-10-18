// Assemble native painted game-map regions in world coordinates. This is the
// development atlas builder; runtime reads one PNG, not a resampled low-res map.
const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const b=path.resolve(__dirname,'../..');
const W=2816,H=1920;
async function load(file){const {data,info}=await sharp(file).removeAlpha().raw().toBuffer({resolveWithObject:true});return {data,width:info.width,height:info.height};}
function road(t,x,y){const i=(y*t.width+x)*3,r=t.data[i],g=t.data[i+1],bl=t.data[i+2];return r>175&&r>g+10&&bl<g*.94;}
function band(t,axis,start,end,otherStart,otherEnd){
 const n=axis==='y'?t.height:t.width,m=axis==='y'?t.width:t.height;
 const counts=[];
 for(let i=Math.floor(start*n);i<Math.ceil(end*n);i++){
  let hits=0,total=0;
  for(let j=Math.floor(otherStart*m);j<Math.floor(otherEnd*m);j+=3){hits+=road(t,axis==='y'?j:i,axis==='y'?i:j);total++;}
  counts.push([i,hits/Math.max(1,total)]);
 }
 const peak=Math.max(...counts.map(p=>p[1]));
 const chosen=counts.filter(p=>p[1]>=Math.max(.25,peak*.55));
 if(!chosen.length)throw Error('Road landmarks not found');
 const lo=chosen[0][0]/n,hi=(chosen[chosen.length-1][0]+1)/n;
 let sum=0,weight=0;for(const [i,v] of chosen){sum+=(i+.5)/n*v;weight+=v;}
 return [lo,sum/weight,hi];
}
function mapAxis(value,target,source){
 const a=[0,...target,1],c=[0,...source,1];
 for(let i=0;i<a.length-1;i++)if(value<=a[i+1])return c[i]+(c[i+1]-c[i])*Math.max(0,Math.min(1,(value-a[i])/(a[i+1]-a[i])));
 return 1;
}
function sample(t,u,v,out){
 const x=Math.max(0,Math.min(t.width-1,u*t.width-.5)),y=Math.max(0,Math.min(t.height-1,v*t.height-.5));
 const x0=Math.floor(x),y0=Math.floor(y),x1=Math.min(x0+1,t.width-1),y1=Math.min(y0+1,t.height-1),fx=x-x0,fy=y-y0;
 const i00=(y0*t.width+x0)*3,i10=(y0*t.width+x1)*3,i01=(y1*t.width+x0)*3,i11=(y1*t.width+x1)*3;
 for(let c=0;c<3;c++)out[c]=(t.data[i00+c]*(1-fx)+t.data[i10+c]*fx)*(1-fy)+(t.data[i01+c]*(1-fx)+t.data[i11+c]*fx)*fy;
}
function smooth(a,b,v){const t=Math.max(0,Math.min(1,(v-a)/(b-a)));return t*t*(3-2*t);}
async function main(){
 const original=await load(path.join(b,'output/adventure game 0.1.5.9/assets/meadow.png'));
 const horizontal=band(original,'y',.35,.65,.05,.65);
 const vertical=band(original,'x',.6,.9,.65,.95);
 const defs=[['nw',0,0],['ne',.45,0],['sw',0,.45],['se',.45,.45]];
 const tiles=[];
 for(const [id,x,y]of defs){
  const texture=await load(path.join(__dirname,'terrain-sources',id+'.png'));
  const sourceY=band(texture,'y',y?0:.55,y?.4:1,.03,.95);
  const targetY=horizontal.map(v=>(v-y)/.55);
  const sourceX=x?band(texture,'x',.3,.8,y?.35:.4,y?.95:.66):null;
  const targetX=x?vertical.map(v=>(v-x)/.55):null;
  if(targetY.some(v=>v<=0||v>=1))throw Error('Road outside overlap: '+id);
  tiles.push({id,x,y,texture,sourceY,targetY,sourceX,targetX});
 }
 const output=Buffer.alloc(W*H*3),pixel=[0,0,0];
 for(let y=0;y<H;y++){
  const v=(y+.5)/H,sy=smooth(.45,.55,v);
  for(let x=0;x<W;x++){
   const u=(x+.5)/W,sx=smooth(.45,.55,u),weights=[(1-sx)*(1-sy),sx*(1-sy),(1-sx)*sy,sx*sy];
   const accum=[0,0,0];
   for(let k=0;k<4;k++)if(weights[k]>0){
    const t=tiles[k];let lu=(u-t.x)/.55,lv=(v-t.y)/.55;
    if(t.targetX)lu=mapAxis(lu,t.targetX,t.sourceX);
    lv=mapAxis(lv,t.targetY,t.sourceY);
    sample(t.texture,lu,lv,pixel);
    for(let c=0;c<3;c++)accum[c]+=pixel[c]*weights[k];
   }
   const offset=(y*W+x)*3;for(let c=0;c<3;c++)output[offset+c]=Math.round(accum[c]);
  }
 }
 const target=path.join(b,'output/adventure game 0.1.5.10/assets/meadow.png');
 await sharp(output,{raw:{width:W,height:H,channels:3}}).png().toFile(target);
 const report={output:[W,H],world:[2200,1500],output_pixels_per_world_unit:[W/2200,H/1500],source_tile_dimensions:tiles.map(t=>({id:t.id,size:[t.texture.width,t.texture.height],bounds:[t.x,t.y,.55,.55],source_road_y:t.sourceY,target_road_y:t.targetY,source_road_x:t.sourceX,target_road_x:t.targetX})),original_road_y:horizontal,original_road_x:vertical,method:'Four independently repainted native regions, aligned to original path landmarks and smoothly blended over10%overlaps. No low-resolution full-map image is enlarged to produce the atlas.',detail_note:'This is newly painted terrain assembled from four native1518x1036regions. Local warp/interpolation aligns roads; output dimensions alone do not guarantee native pixel detail at every location.'};
 fs.writeFileSync(path.join(__dirname,'terrain-atlas-build.json'),JSON.stringify(report,null,2));
 console.log('NATIVE_TERRAIN_ATLAS_READY',W,H,'originalroad',horizontal,vertical);
}
main().catch(e=>{console.error(e);process.exitCode=1});
