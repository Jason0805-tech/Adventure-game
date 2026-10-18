const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const folder=path.join(__dirname,'captures');
const xml=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;');
const rgba=c=>`rgb(${c.slice(0,3).map(v=>Math.round(v*255)).join(',')})`;
const cache=new Map();
function snapshotSvg(data){
 const defs=[],body=[],ids=new Map(),filters=new Map();
 for(const c of data.commands){
  const [tx,ty,a,sx,sy]=c.transform;
  const trans=`translate(${tx} ${ty}) rotate(${a*180/Math.PI}) scale(${sx} ${sy})`;
  const color=c.color||[1,1,1,1];let shape='';
  if(c.kind==='texture'){
   let id=ids.get(c.texture.path);
   if(!id){id='t'+ids.size;ids.set(c.texture.path,id);let encoded=cache.get(c.texture.path);if(!encoded){encoded=fs.readFileSync(c.texture.path).toString('base64');cache.set(c.texture.path,encoded)}defs.push(`<image id="${id}" width="${c.texture.width}" height="${c.texture.height}" href="data:image/png;base64,${encoded}"/>`)}
   let filter='';if(color.slice(0,3).some(v=>Math.abs(v-1)>.001)){const key=color.slice(0,3).join('_');let fid=filters.get(key);if(!fid){fid='f'+filters.size;filters.set(key,fid);defs.push(`<filter id="${fid}" color-interpolation-filters="sRGB" x="-100%" y="-100%" width="300%" height="300%"><feColorMatrix type="matrix" values="${color[0]} 0 0 0 0  0 ${color[1]} 0 0 0  0 0 ${color[2]} 0 0  0 0 0 1 0"/></filter>`)}filter=` filter="url(#${fid})"`}
   const [x,y,w,h]=c.rect,src=c.source||[0,0,c.texture.width,c.texture.height];
   shape=`<svg x="${x}" y="${y}" width="${w}" height="${h}" viewBox="${src.join(' ')}" preserveAspectRatio="none" overflow="hidden" opacity="${color[3]}"><use href="#${id}"${filter}/></svg>`;
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
(async()=>{
 const names=fs.readdirSync(folder).filter(x=>x.endsWith('.json'));
 for(let i=0;i<names.length;i+=4)await Promise.all(names.slice(i,i+4).map(async name=>{
  const svg=snapshotSvg(JSON.parse(fs.readFileSync(path.join(folder,name))));
  await sharp(Buffer.from(svg)).png().toFile(path.join(folder,name.replace('.json','.png')));
 }));
 console.log('Rendered',names.length,'scene command captures');
})();
