const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const sharp = require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const {prepareTextureRasters, snapshotSvg} = require('./render_captures.cjs');
const captures = path.join(__dirname, 'captures');
const output = path.join(__dirname, 'quality-comparisons');
fs.mkdirSync(output, {recursive:true});
const xml = value => String(value).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;');
const label = (text,width,height=32) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}"><rect width="100%" height="100%" fill="#f1ead9"/><text x="12" y="22" font-family="Arial" font-size="15" fill="#304c3c">${xml(text)}</text></svg>`);
async function render(name, scale) {
  const data = JSON.parse(fs.readFileSync(path.join(captures,name+'.json'),'utf8'));
  data.width *= scale; data.height *= scale;
  for (const command of data.commands) {
    const t = command.transform;
    t[0] *= scale; t[1] *= scale; t[3] *= scale; t[4] *= scale;
  }
  await prepareTextureRasters(data);
  return sharp(Buffer.from(snapshotSvg(data))).png().toBuffer();
}
async function main() {
  const baselineManifest=JSON.parse(fs.readFileSync(path.join(__dirname,'quality-scenes-baseline.json'),'utf8'));
  const finalManifest=JSON.parse(fs.readFileSync(path.join(__dirname,'quality-scenes-final.json'),'utf8'));
  for(const previous of baselineManifest.scenes){
    const current=finalManifest.scenes.find(scene=>scene.name===previous.name);
    for(const key of ['camera','player','size']) if(JSON.stringify(previous[key])!==JSON.stringify(current[key])) throw new Error('Comparison changed '+key+' in '+previous.name);
    if(!previous.player_walkable||!current.player_walkable) throw new Error('Comparison actor is inside a blocker: '+previous.name);
  }
  const summaries=[];
  for (const scene of ['camp','forest','pond']) {
    const paths={};
    for (const scale of [1,2]) {
      const width=640*scale,height=480*scale;
      const oldName='quality-baseline-'+scene,newName='quality-final-'+scene;
      const [before,after] = await Promise.all([render(oldName,scale),render(newName,scale)]);
      const comparison=path.join(output,`${scene}-${scale}x.png`);
      await sharp({create:{width:width*2,height:height+64,channels:4,background:'#f1ead9'}}).composite([
        {input:label('0.1.5.9 - reduced environment textures',width),left:0,top:0},
        {input:label('0.1.5.10 - high resolution actor and environment',width),left:width,top:0},
        {input:before,left:0,top:32},{input:after,left:width,top:32},
        {input:label(`Same seed, camera, actor pose, time | ${scale}x Canvas resolution | software replay, not a native GPU frame`,width*2),left:0,top:height+32}
      ]).png().toFile(comparison);
      if(scale===1) {
        await sharp(before).png().toFile(path.join(captures,oldName+'.png'));
        await sharp(after).png().toFile(path.join(captures,newName+'.png'));
      }
      paths[scale+'x']=comparison;
    }
    summaries.push({scene,outputs:paths});
  }
  // A close crop uses the actual 2x Canvas replay above, not an enlarged 1x PNG.
  for (const [scene,center] of [['camp',[280,370]],['forest',[320,360]],['pond',[320,400]]]) {
    const pieces=[];
    for(const [index,tag] of ['baseline','final'].entries()){
      const raster=await render('quality-'+tag+'-'+scene,2);
      const patch=await sharp(raster).extract({left:Math.round((center[0]-100)*2),top:Math.round((center[1]-140)*2),width:400,height:360}).png().toBuffer();
      pieces.push({input:patch,left:index*400,top:32});
      pieces.push({input:label(tag==='baseline'?'0.1.5.9':'0.1.5.10',400),left:index*400,top:0});
    }
    pieces.push({input:label('Actor and nearby objects | 2x Canvas replay of source textures',800),left:0,top:392});
    await sharp({create:{width:800,height:424,channels:4,background:'#f1ead9'}}).composite(pieces).png().toFile(path.join(output,scene+'-actor-detail-2x.png'));
  }
  const root=path.resolve(__dirname,'../..');
  const assets=version=>path.join(root,'output','adventure game '+version,'assets');
  const actorSources=['traveler-unarmed-directions.png','traveler-armed-directions.png','traveler-use-directions.png'];
  const actorIntegrity=[];
  for(const name of actorSources){
    const files=['0.1.5.9','0.1.5.10'].map(version=>path.join(assets(version),name));
    const [oldInfo,newInfo]=await Promise.all(files.map(file=>sharp(file).metadata()));
    if(newInfo.width!==oldInfo.width*2||newInfo.height!==oldInfo.height*2)throw new Error('Actor atlas does not contain true doubled raster dimensions: '+name);
    actorIntegrity.push({source:name,previous_size:[oldInfo.width,oldInfo.height],new_size:[newInfo.width,newInfo.height],sha256:crypto.createHash('sha256').update(fs.readFileSync(files[1])).digest('hex')});
  }
  const normal=['0.1.5.9','0.1.5.10'].map(version=>JSON.parse(fs.readFileSync(path.join(assets(version),'traveler-directions.json'),'utf8')));
  const actions=['0.1.5.9','0.1.5.10'].map(version=>JSON.parse(fs.readFileSync(path.join(assets(version),'tool-use-meta.json'),'utf8')));
  const eq=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const scaled=(oldValues,newValues)=>oldValues.length===newValues.length&&oldValues.every((v,i)=>Math.abs(v*2-newValues[i])<1e-9);
  if(!scaled(normal[0].cell,normal[1].cell)||!scaled(normal[0].anchor,normal[1].anchor)||!eq(normal[0].angles,normal[1].angles)||!eq(normal[0].local_right_hand,normal[1].local_right_hand)||normal[0].stride!==normal[1].stride)throw new Error('HD actor changed cell, heading, hand convention or world stride');
  let poseChecks=0;
  for(let i=0;i<normal[0].frames.length;i++){
    const oldFrame=normal[0].frames[i],newFrame=normal[1].frames[i];
    if(oldFrame.angle!==newFrame.angle||oldFrame.frame!==newFrame.frame||!eq(oldFrame.legs,newFrame.legs)||!eq(oldFrame.grip_3d,newFrame.grip_3d)||!scaled(oldFrame.right_hand,newFrame.right_hand)||Math.abs(oldFrame.hand_depth-newFrame.hand_depth)>1e-9||Math.abs(oldFrame.body_bob_pixels*2-newFrame.body_bob_pixels)>1e-9)throw new Error('HD normal pose changed: '+i);
    poseChecks++;
  }
  if(!eq(Object.keys(actions[0]),Object.keys(actions[1])))throw new Error('HD action frame set changed');
  for(const key of Object.keys(actions[0])){
    const previous=actions[0][key],current=actions[1][key];
    if(previous.angle!==current.angle||previous.frame!==current.frame||!eq(previous.grip_3d,current.grip_3d)||!scaled(previous.right_hand,current.right_hand)||!scaled(previous.rod_tip,current.rod_tip))throw new Error('HD action grip/rod tip changed: '+key);
    poseChecks++;
  }
  const actorBounds=[];
  for(const scene of ['camp','forest','pond']){
    const pairs=['baseline','final'].map((tag,index)=>{
      const data=JSON.parse(fs.readFileSync(path.join(captures,'quality-'+tag+'-'+scene+'.json'),'utf8'));
      const [width,height]=index===0?actorIntegrity[0].previous_size:actorIntegrity[0].new_size;
      const commands=data.commands.filter(c=>c.kind==='texture'&&c.texture.width===width&&c.texture.height===height&&c.source&&c.source[2]===normal[index].cell[0]&&c.source[3]===normal[index].cell[1]);
      if(commands.length!==1)throw new Error('Expected one unarmed actor draw in '+tag+' '+scene+', got '+commands.length);
      return commands[0];
    });
    if(!eq(pairs[0].rect,pairs[1].rect)||!eq(pairs[0].transform,pairs[1].transform))throw new Error('HD actor world bounds or transform changed: '+scene);
    actorBounds.push({scene,world_rectangle:pairs[1].rect,transform:pairs[1].transform,world_bounds_unchanged:true});
  }
  const groundRasters=['baseline','final'].map(tag=>{
    const data=JSON.parse(fs.readFileSync(path.join(captures,'quality-'+tag+'-camp.json'),'utf8'));
    const command=data.commands[0];
    return {tag,source_texture_pixels:[command.texture.width,command.texture.height],world_rectangle:command.rect};
  });
  fs.writeFileSync(path.join(output,'manifest.json'),JSON.stringify({method:'Identical seeded scenes captured from actual runtime Canvas calls. 1x and 2x software rasterization. 2x output replays the original source textures at twice the Canvas scale and does not resize a 1x screenshot. Final actor atlases are rerendered at doubled pixel dimensions; normalized poses, grips and actual world drawing bounds are checked against 0.1.5.9. No native GPU or physical Retina screenshot claim.',same_pose_seed_time:true,all_player_positions_walkable:true,hd_actor_atlases:actorIntegrity,normalized_pose_grip_frames_checked:poseChecks,hd_actor_world_bounds:actorBounds,actual_ground_rasters:groundRasters,comparisons:summaries},null,2));
  console.log('QUALITY_COMPARISONS_READY',summaries.length,'scenes, 6 full comparisons and 3 actor details');
}
main().catch(error=>{console.error(error);process.exitCode=1});
