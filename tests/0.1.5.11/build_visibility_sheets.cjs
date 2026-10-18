const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const base=__dirname,out=path.join(base,'visual-acceptance');
const xml=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const label=(s,w,h)=>Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}"><rect width="100%" height="100%" fill="#eee8d7"/><text x="8" y="18" font-family="Arial" font-size="12" fill="#35483d">${xml(s)}</text></svg>`);
async function main(){
 fs.mkdirSync(out,{recursive:true});
 const report=JSON.parse(fs.readFileSync(path.join(base,'back-front-visibility-final.json')));
 const sources=report.captures;
 for(let offset=0;offset<sources.length;offset+=16){
  const items=sources.slice(offset,offset+16),layers=[],rows=Math.ceil(items.length/4);
  layers.push({input:label('0.1.5.11 | front / behind ground solids | actual Canvas replay',880,28),left:0,top:0});
  for(let i=0;i<items.length;i++){
   const item=items[i],x=i%4*220,y=Math.floor(i/4)*196+28;
   layers.push({input:await sharp(path.join(base,'captures',item.file+'.png')).resize(220,170).png().toBuffer(),left:x,top:y});
   layers.push({input:label(item.name,220,26),left:x,top:y+170});
  }
  await sharp({create:{width:880,height:rows*196+28,channels:4,background:'#eee8d7'}}).composite(layers).png().toFile(path.join(out,`model-front-back-${Math.floor(offset/16)+1}.png`));
 }
 for(const name of ['cabin-back','gate-center-245','gate-center-275','tree_0-back','tree_1-back','tree_2-back']){
  if(!sources.some(x=>x.name===name))continue;
  const layers=[];
  for(const [i,tag] of ['fixed-baseline','final'].entries()){
   const source=path.join(base,'captures',`visibility-${tag}-${name}.png`);
   layers.push({input:await sharp(source).png().toBuffer(),left:i*440,top:28});
   layers.push({input:label(i?'0.1.5.11 | ground footprints + overhead paint':'0.1.5.10 | previous render',440,28),left:i*440,top:0});
  }
  layers.push({input:label(name+' | exact same actor/camera pose | software Canvas replay',880,28),left:0,top:368});
  await sharp({create:{width:880,height:396,channels:4,background:'#eee8d7'}}).composite(layers).png().toFile(path.join(out,name+'-before-after.png'));
 }
 console.log('VISIBILITY_SHEETS_READY',sources.length,'scenes');
}
main().catch(error=>{console.error(error);process.exitCode=1});
