const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const b=__dirname;
const xml=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
async function label(text,width,height){return Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="100%" height="100%" fill="#efead9"/><text x="8" y="17" font-family="Arial" font-size="12" fill="#35483d">${xml(text)}</text></svg>`)}
async function main(){
 const m=JSON.parse(fs.readFileSync(path.join(b,'model-contact-capture-manifest.json')));
 const out=path.join(b,'contact-sheets');fs.mkdirSync(out,{recursive:true});
 for(let start=0;start<m.captures.length;start+=20){
  const items=m.captures.slice(start,start+20),rows=Math.ceil(items.length/4),layers=[];
  layers.push({input:await label('0.1.5.9 | actual model contacts | software Canvas replays',880,28),left:0,top:0});
  for(let i=0;i<items.length;i++){
   const x=(i%4)*220,y=Math.floor(i/4)*196+28;
   const picture=await sharp(items[i].png).resize(220,170).png().toBuffer();
   layers.push({input:picture,left:x,top:y});
   layers.push({input:await label(items[i].label,220,26),left:x,top:y+170});
  }
  await sharp({create:{width:880,height:rows*196+28,channels:4,background:'#efead9'}}).composite(layers).png().toFile(path.join(out,`models-${Math.floor(start/20)+1}.png`));
 }
 const layers=[];
 for(const [i,name] of ['world-before-cabin','world-after-cabin'].entries()){
  layers.push({input:await sharp(path.join(b,'captures',name+'.png')).resize(440,340).png().toBuffer(),left:i*440,top:28});
  layers.push({input:await label(i?'0.1.5.9 - corrected front contact':'0.1.5.8 - previous occlusion',440,28),left:i*440,top:0});
 }
 layers.push({input:await label('Same legal player position | software replay of actual game drawing commands',880,28),left:0,top:368});
 await sharp({create:{width:880,height:396,channels:4,background:'#efead9'}}).composite(layers).png().toFile(path.join(out,'cabin-before-after.png'));
 console.log('CONTACT_SHEETS_READY',Math.ceil(m.captures.length/20),'pages',m.captures.length,'contacts');
}
main().catch(e=>{console.error(e);process.exitCode=1});
