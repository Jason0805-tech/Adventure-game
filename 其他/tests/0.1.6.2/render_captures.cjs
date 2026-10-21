const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const folder=path.join(__dirname,'captures');
const xml=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const rgba=c=>`rgb(${c.slice(0,3).map(v=>Math.round(v*255)).join(',')})`;
const cache=new Map();
const meshCache=new Map();
const pixelCache=new Map();
const n=value=>Number(value.toFixed(3));
const close=(a,b)=>Math.abs(a-b)<=0.0001;
function textureMapping(command){
 if(command.kind!=='texture')return null;
 const source=command.source||[0,0,command.texture.width,command.texture.height];
 const [x,y,w,h]=command.rect;
 if(w<=0||h<=0||source[2]<=0||source[3]<=0)return null;
 const sx=w/source[2],sy=h/source[3];
 return {source,scale:[sx,sy],origin:[x-source[0]*sx,y-source[1]*sy]};
}
function sameTextureMapping(a,b){
 if(a.kind!=='texture'||b.kind!=='texture'||a.texture.path!==b.texture.path)return false;
 if(!a.transform.every((value,index)=>close(value,b.transform[index])))return false;
 const ac=a.color||[1,1,1,1],bc=b.color||[1,1,1,1];
 if(!ac.every((value,index)=>close(value,bc[index])))return false;
 const am=textureMapping(a),bm=textureMapping(b);
 return am&&bm&&am.scale.every((value,index)=>close(value,bm.scale[index]))&&am.origin.every((value,index)=>close(value,bm.origin[index]));
}
function mergeSourceSpans(sources){
 // Bands share a source-row interval. Merge touching x spans into a single
 // clipping rectangle, while retaining genuinely disjoint source areas.
 const rows=[];
 for(const source of sources){
  let row=rows.find(candidate=>close(candidate.y,source[1])&&close(candidate.h,source[3]));
  if(!row){row={y:source[1],h:source[3],spans:[]};rows.push(row);}
  row.spans.push([source[0],source[0]+source[2]]);
 }
 const rectangles=[];
 for(const row of rows){
  row.spans.sort((a,b)=>a[0]-b[0]);
  const merged=[];
  for(const span of row.spans){
   const last=merged[merged.length-1];
   if(last&&span[0]<=last[1]+0.0001)last[1]=Math.max(last[1],span[1]);
   else merged.push(span.slice());
  }
  for(const [left,right] of merged)rectangles.push([left,row.y,right-left,row.h]);
 }
 return rectangles;
}
function coalesceTextureRuns(commands){
 const result=[];
 for(let i=0;i<commands.length;){
  const first=commands[i],mapping=textureMapping(first);
  if(!mapping){result.push(first);i++;continue;}
  const sources=[mapping.source];let end=i+1;
  // Never cross a different painter command: depth-interleaved actors and
  // foreground bands keep exactly their recorded ordering.
  while(end<commands.length&&sameTextureMapping(first,commands[end])){
   const incoming=textureMapping(commands[end]).source;
   // Overlapping translucent draws are separate source-over operations;
   // collapsing their overlap would change its opacity.
   const overlaps=sources.some(source=>Math.min(source[0]+source[2],incoming[0]+incoming[2])-Math.max(source[0],incoming[0])>0.0001&&Math.min(source[1]+source[3],incoming[1]+incoming[3])-Math.max(source[1],incoming[1])>0.0001);
   if(overlaps)break;
   sources.push(incoming);end++;
  }
  result.push({...first,replayMapping:mapping,replaySpans:mergeSourceSpans(sources),replayCommandCount:end-i});
  i=end;
 }
 return result;
}
async function texturePixels(texture){
 if(!pixelCache.has(texture.path))pixelCache.set(texture.path,sharp(texture.path).ensureAlpha().raw().toBuffer({resolveWithObject:true}));
 if(pixelCache.size>256)pixelCache.delete(pixelCache.keys().next().value);
 return pixelCache.get(texture.path);
}
async function prepareTextureRasters(data){
 const commands=coalesceTextureRuns(data.commands);
 data.replayCommands=commands;
 for(const command of commands){
  if(!command.replayMapping)continue;
  const {origin:[ox,oy],scale:[mx,my]}=command.replayMapping;
  const [tx,ty,angle,sx,sy]=command.transform;
  if(!sx||!sy)continue;
  const cos=Math.cos(angle),sin=Math.sin(angle);
  const forward=(u,v)=>{
   const x=(ox+u*mx)*sx,y=(oy+v*my)*sy;
   return [tx+x*cos-y*sin,ty+x*sin+y*cos];
  };
  const corners=command.replaySpans.flatMap(([x,y,w,h])=>[
   forward(x,y),forward(x+w,y),forward(x,y+h),forward(x+w,y+h)
  ]);
  const x=Math.max(0,Math.floor(Math.min(...corners.map(point=>point[0]))));
  const y=Math.max(0,Math.floor(Math.min(...corners.map(point=>point[1]))));
  const right=Math.min(data.width,Math.ceil(Math.max(...corners.map(point=>point[0]))));
  const bottom=Math.min(data.height,Math.ceil(Math.max(...corners.map(point=>point[1]))));
  if(right<=x||bottom<=y){command.replayRaster={empty:true};continue;}
  const width=right-x,height=bottom-y;
  const {data:pixels,info}=await texturePixels(command.texture);
  const target=Buffer.alloc(width*height*4),color=command.color||[1,1,1,1];
  for(let py=0;py<height;py++)for(let px=0;px<width;px++){
   const dx=x+px+0.5-tx,dy=y+py+0.5-ty;
   const localX=(dx*cos+dy*sin)/sx,localY=(-dx*sin+dy*cos)/sy;
   const u=(localX-ox)/mx,v=(localY-oy)/my;
   if(!command.replaySpans.some(([left,top,w,h])=>u>=left&&u<left+w&&v>=top&&v<top+h))continue;
   // Ordinary non-MSAA Canvas triangles use pixel-center coverage. Sampling
   // from the complete source image avoids inventing antialiased strip edges
   // at every source-region boundary. Texture filtering remains bilinear.
   const sampleX=Math.max(0,Math.min(info.width-1,u-0.5));
   const sampleY=Math.max(0,Math.min(info.height-1,v-0.5));
   const x0=Math.floor(sampleX),y0=Math.floor(sampleY),x1=Math.min(info.width-1,x0+1),y1=Math.min(info.height-1,y0+1);
   const fx=sampleX-x0,fy=sampleY-y0;
   const weights=[(1-fx)*(1-fy),fx*(1-fy),(1-fx)*fy,fx*fy];
   const offsets=[(y0*info.width+x0)*4,(y0*info.width+x1)*4,(y1*info.width+x0)*4,(y1*info.width+x1)*4];
   const targetOffset=(py*width+px)*4;
   for(let channel=0;channel<4;channel++){
    let value=0;
    for(let sample=0;sample<4;sample++)value+=pixels[offsets[sample]+channel]*weights[sample];
    target[targetOffset+channel]=Math.max(0,Math.min(255,Math.round(value*color[channel])));
   }
  }
  const encoded=await sharp(target,{raw:{width,height,channels:4}}).png().toBuffer();
  command.replayRaster={x,y,width,height,encoded:encoded.toString('base64')};
 }
}
function triangleSamples(vertices, ids, bounds, visit){
 const [a,b,c]=ids.map(id=>vertices[id]);
 const den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1]);
 if(Math.abs(den)<1e-9)return;
 const [left,top,width,height]=bounds;
 const minX=Math.max(left,Math.floor(Math.min(a[0],b[0],c[0]))),maxX=Math.min(left+width,Math.ceil(Math.max(a[0],b[0],c[0])));
 const minY=Math.max(top,Math.floor(Math.min(a[1],b[1],c[1]))),maxY=Math.min(top+height,Math.ceil(Math.max(a[1],b[1],c[1])));
 for(let y=minY;y<maxY;y++)for(let x=minX;x<maxX;x++){
  const px=x+.5,py=y+.5;
  const u=((b[1]-c[1])*(px-c[0])+(c[0]-b[0])*(py-c[1]))/den;
  const v=((c[1]-a[1])*(px-c[0])+(a[0]-c[0])*(py-c[1]))/den;
  const w=1-u-v;
  if(u>=-1e-7&&v>=-1e-7&&w>=-1e-7){
   // Give shared edges to exactly one triangle, as Canvas rasterization does.
   const edges=[[b,c],[c,a],[a,b]],weights=[u,v,w];
   const covered=weights.every((weight,index)=>{
    if(Math.abs(weight)>1e-7)return true;
    let [start,end]=edges[index];if(den<0)[start,end]=[end,start];
    const dx=end[0]-start[0],dy=end[1]-start[1];
    return dy<0||(Math.abs(dy)<1e-9&&dx>0);
   });
   if(covered)visit(x,y,[u,v,w]);
  }
 }
}
function meshKey(command){return command.mesh.path+'|'+Math.max(1,Math.abs(command.transform[3]),Math.abs(command.transform[4]))+'|'+(command.texture?.path||'');}
async function prepareMesh(command){
 const key=meshKey(command);
 if(meshCache.has(key))return;
 const data=JSON.parse(fs.readFileSync(command.mesh.path,'utf8'));
 const tex=command.texture?await texturePixels(command.texture):null;
 const [bx,by,bw,bh]=data.bounds;
 // Rasterize enlarged Canvas QA views at their final screen density, just as
 // native triangles do, instead of scaling a 1x limb bitmap to 2x afterwards.
 const density=Math.max(1,Math.abs(command.transform[3]),Math.abs(command.transform[4]));
 const x=Math.floor(bx*density),y=Math.floor(by*density),width=Math.max(1,Math.ceil((bx+bw)*density)-x),height=Math.max(1,Math.ceil((by+bh)*density)-y);
 const target=Buffer.alloc(width*height*4);let triangles=0;
 for(const surface of data.surfaces){
  if(surface.primitive!==3)throw new Error('Software mesh capture only supports runtime triangle surfaces');
  const vertices=surface.vertices.map(v=>[v[0]*density,v[1]*density]),colors=surface.colors,indices=surface.indices.length?surface.indices:vertices.map((_,i)=>i);
  for(let i=0;i+2<indices.length;i+=3){
   const ids=indices.slice(i,i+3);
   triangleSamples(vertices,ids,[x,y,width,height],(px,py,weights)=>{
    const at=((py-y)*width+px-x)*4;
    const source=[];
    for(let ch=0;ch<4;ch++){
     let value=0;
     for(let j=0;j<3;j++)value+=(colors[ids[j]]||[1,1,1,1])[ch]*weights[j];
     source.push(Math.max(0,Math.min(1,value)));
    }
    if(tex&&surface.uvs?.length){
     let u=0,v=0;
     for(let j=0;j<3;j++){u+=surface.uvs[ids[j]][0]*weights[j];v+=surface.uvs[ids[j]][1]*weights[j];}
     const fx=Math.max(0,Math.min(tex.info.width-1,u*tex.info.width-.5)),fy=Math.max(0,Math.min(tex.info.height-1,v*tex.info.height-.5));
     const ix=Math.floor(fx),iy=Math.floor(fy),rx=fx-ix,ry=fy-iy;
     const offsets=[(iy*tex.info.width+ix)*4,(iy*tex.info.width+Math.min(ix+1,tex.info.width-1))*4,(Math.min(iy+1,tex.info.height-1)*tex.info.width+ix)*4,(Math.min(iy+1,tex.info.height-1)*tex.info.width+Math.min(ix+1,tex.info.width-1))*4];
     const blend=[(1-rx)*(1-ry),rx*(1-ry),(1-rx)*ry,rx*ry];
     for(let ch=0;ch<4;ch++){
      let value=0;for(let j=0;j<4;j++)value+=tex.data[offsets[j]+ch]*blend[j];
      source[ch]*=value/255;
     }
    }
    // Later translucent pigment strokes blend over the opaque limb underneath.
    const oldAlpha=target[at+3]/255,newAlpha=source[3]+oldAlpha*(1-source[3]);
    for(let ch=0;ch<3;ch++)target[at+ch]=newAlpha?Math.round(255*(source[ch]*source[3]+target[at+ch]/255*oldAlpha*(1-source[3]))/newAlpha):0;
    target[at+3]=Math.round(newAlpha*255);
   });triangles++;
  }
 }
 const encoded=await sharp(target,{raw:{width,height,channels:4}}).png().toBuffer();
 const pngPath=command.mesh.path.replace(/\.json$/,'-d'+density+'.png');
 fs.writeFileSync(pngPath,encoded);
 meshCache.set(key,{path:pngPath,bounds:[x/density,y/density,width/density,height/density],pixels:[width,height],encoded:encoded.toString('base64'),triangles});
 console.log('MESH_REPLAY_CACHE',path.basename(pngPath),triangles,'triangles; barycentric vertex colours');
}
async function prepareTexturedPolygons(data){
 for(const c of data.replayCommands||data.commands){
  if(c.kind!=='textured_polygon')continue;
  const [tx,ty,a,sx,sy]=c.transform,cos=Math.cos(a),sin=Math.sin(a);
  const vertices=c.points.map(([px,py])=>[tx+px*sx*cos-py*sy*sin,ty+px*sx*sin+py*sy*cos]);
  const x=Math.max(0,Math.floor(Math.min(...vertices.map(p=>p[0])))),y=Math.max(0,Math.floor(Math.min(...vertices.map(p=>p[1]))));
  const right=Math.min(data.width,Math.ceil(Math.max(...vertices.map(p=>p[0])))),bottom=Math.min(data.height,Math.ceil(Math.max(...vertices.map(p=>p[1]))));
  const width=right-x,height=bottom-y;
  if(width<=0||height<=0){c.replayRaster={empty:true};continue;}
  const {data:pixels,info}=await texturePixels(c.texture),target=Buffer.alloc(width*height*4),color=c.color||[1,1,1,1];
  for(let i=0;i+2<c.triangles.length;i+=3){
   const ids=c.triangles.slice(i,i+3);
   triangleSamples(vertices,ids,[x,y,width,height],(px,py,weights)=>{
    let u=0,v=0;
    for(let j=0;j<3;j++){u+=c.uvs[ids[j]][0]*weights[j];v+=c.uvs[ids[j]][1]*weights[j];}
    const fx=Math.max(0,Math.min(info.width-1,u*info.width-.5)),fy=Math.max(0,Math.min(info.height-1,v*info.height-.5));
    const x0=Math.floor(fx),y0=Math.floor(fy),x1=Math.min(info.width-1,x0+1),y1=Math.min(info.height-1,y0+1);
    const wx=fx-x0,wy=fy-y0;
    const ws=[(1-wx)*(1-wy),wx*(1-wy),(1-wx)*wy,wx*wy],at=((py-y)*width+px-x)*4;
    const offsets=[(y0*info.width+x0)*4,(y0*info.width+x1)*4,(y1*info.width+x0)*4,(y1*info.width+x1)*4];
    for(let ch=0;ch<4;ch++){
     let value=0;for(let j=0;j<4;j++)value+=pixels[offsets[j]+ch]*ws[j];
     target[at+ch]=Math.max(0,Math.min(255,Math.round(value*color[ch])));
    }
   });
  }
  c.replayRaster={x,y,width,height,encoded:(await sharp(target,{raw:{width,height,channels:4}}).png().toBuffer()).toString('base64')};
 }
}
function snapshotSvg(data){
 const defs=[],body=[],ids=new Map(),filters=new Map();
 for(const c of data.replayCommands||coalesceTextureRuns(data.commands)){
  const [tx,ty,a,sx,sy]=c.transform;
  const trans=`translate(${tx} ${ty}) rotate(${a*180/Math.PI}) scale(${sx} ${sy})`;
  const color=c.color||[1,1,1,1];let shape='';
  if(c.replayRaster){
   const r=c.replayRaster;
   if(!r.empty)body.push(`<image x="${r.x}" y="${r.y}" width="${r.width}" height="${r.height}" href="data:image/png;base64,${r.encoded}"/>`);
   continue;
  }
  if(c.kind==='texture'){
   if(c.replayRaster){
    const raster=c.replayRaster;
    if(!raster.empty)body.push(`<image x="${raster.x}" y="${raster.y}" width="${raster.width}" height="${raster.height}" href="data:image/png;base64,${raster.encoded}"/>`);
    continue;
   }
   let id=ids.get(c.texture.path);
   if(!id){id='t'+ids.size;ids.set(c.texture.path,id);let encoded=cache.get(c.texture.path);if(!encoded){encoded=fs.readFileSync(c.texture.path).toString('base64');cache.set(c.texture.path,encoded)}defs.push(`<image id="${id}" width="${c.texture.width}" height="${c.texture.height}" href="data:image/png;base64,${encoded}"/>`)}
   let filter='';if(color.slice(0,3).some(v=>Math.abs(v-1)>.001)){const key=color.slice(0,3).join('_');let fid=filters.get(key);if(!fid){fid='f'+filters.size;filters.set(key,fid);defs.push(`<filter id="${fid}" color-interpolation-filters="sRGB" x="-100%" y="-100%" width="300%" height="300%"><feColorMatrix type="matrix" values="${color[0]} 0 0 0 0  0 ${color[1]} 0 0 0  0 0 ${color[2]} 0 0  0 0 0 1 0"/></filter>`)}filter=` filter="url(#${fid})"`}
   if(c.replayMapping){
    const {origin:[ox,oy],scale:[mx,my]}=c.replayMapping;
    const clipId='clip'+defs.length;
    const rects=c.replaySpans.map(([x,y,w,h])=>`<rect x="${ox+x*mx}" y="${oy+y*my}" width="${w*mx}" height="${h*my}"/>`).join('');
    // Each band used to be a separately antialiased nested SVG viewport.
    // That blended the background through every fractional internal edge.
    // A union clip samples the same full texture once per uninterrupted run;
    // hard clip coverage avoids artificial seams across intervening draws.
    // This remains software Canvas replay, not a native GPU screenshot.
    defs.push(`<clipPath id="${clipId}" clipPathUnits="userSpaceOnUse" shape-rendering="crispEdges">${rects}</clipPath>`);
    shape=`<g clip-path="url(#${clipId})" opacity="${color[3]}"><use href="#${id}" transform="translate(${ox} ${oy}) scale(${mx} ${my})"${filter}/></g>`;
   }else{
    const [x,y,w,h]=c.rect,src=c.source||[0,0,c.texture.width,c.texture.height];
    shape=`<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="${src.join(' ')}" preserveAspectRatio="none" overflow="hidden" opacity="${color[3]}"><use href="#${id}"${filter}/></svg>`;
   }
  }else if(c.kind==='mesh'){
   const mesh=meshCache.get(meshKey(c));if(!mesh)throw new Error('Mesh was not prepared: '+c.mesh.path);
   let id=ids.get(meshKey(c));
   const [x,y,w,h]=mesh.bounds;
   if(!id){id='m'+ids.size;ids.set(meshKey(c),id);defs.push(`<image id="${id}" width="${w}" height="${h}" href="data:image/png;base64,${mesh.encoded}"/>`);}
   shape=`<g transform="matrix(${(c.mesh_transform||[1,0,0,1,0,0]).join(' ')})" opacity="${color[3]}"><use href="#${id}" x="${x}" y="${y}"/></g>`;
  }else if(c.kind==='rect'||c.kind==='panel'){
   const [x,y,w,h]=c.rect;const fill=c.kind==='panel'||c.filled?rgba(color):'none';
   const stroke=c.kind==='panel'?rgba(c.border):(!c.filled?rgba(color):'none');
   shape=`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${c.radius||0}" fill="${fill}" stroke="${stroke}" stroke-width="${c.width||1}" opacity="${color[3]}"/>`;
  }else if(c.kind==='circle')shape=`<circle cx="${c.p[0]}" cy="${c.p[1]}" r="${c.radius}" fill="${c.filled?rgba(color):'none'}" stroke="${c.filled?'none':rgba(color)}" opacity="${color[3]}"/>`;
  else if(c.kind==='line')shape=`<line x1="${c.a[0]}" y1="${c.a[1]}" x2="${c.b[0]}" y2="${c.b[1]}" stroke="${rgba(color)}" stroke-width="${c.width}" opacity="${color[3]}"/>`;
  else if(c.kind==='polygon'||c.kind==='polyline')shape=`<${c.kind} points="${c.points.map(p=>p.join(',')).join(' ')}" fill="${c.kind==='polygon'?rgba(color):'none'}" stroke="${c.kind==='polyline'?rgba(color):'none'}" stroke-width="${c.width||1}" opacity="${color[3]}"/>`;
  else if(c.kind==='text')shape=`<text x="${c.p[0]}" y="${c.p[1]}" font-family="Arial, sans-serif" font-size="${c.size}" fill="${rgba(color)}" opacity="${color[3]}">${xml(c.text)}</text>`;
  body.push(`<g transform="${trans}">${shape}</g>`);
 }
 return `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="${data.width}" height="${data.height}" viewBox="0 0 ${data.width} ${data.height}"><defs>${defs.join('')}</defs>${body.join('')}</svg>`;
}
async function main(){
 const requested=process.argv.slice(2);
 const names=requested.length?requested.map(name=>name.endsWith('.json')?name:name+'.json'):fs.readdirSync(folder).filter(x=>x.endsWith('.json')&&!x.startsWith('mesh-'));
 const captures=names.map(name=>JSON.parse(fs.readFileSync(path.join(folder,name),'utf8')));
 const uniqueMeshes=new Map();
 for(const capture of captures)for(const command of capture.commands)if(command.kind==='mesh')uniqueMeshes.set(meshKey(command),command);
 for(const command of uniqueMeshes.values())await prepareMesh(command);
 for(let i=0;i<names.length;i+=4)await Promise.all(names.slice(i,i+4).map(async name=>{
  const capture=captures[names.indexOf(name)];
  await prepareTextureRasters(capture);
  await prepareTexturedPolygons(capture);
  const svg=snapshotSvg(capture);
  await sharp(Buffer.from(svg)).png().toFile(path.join(folder,name.replace('.json','.png')));
 }));
 console.log('Rendered',names.length,'software Canvas command captures (not native GPU frames)');
}
module.exports={triangleSamples,prepareMesh,prepareTexturedPolygons,textureMapping,sameTextureMapping,mergeSourceSpans,coalesceTextureRuns,prepareTextureRasters,snapshotSvg};
if(require.main===module)main().catch(error=>{console.error(error);process.exitCode=1});
