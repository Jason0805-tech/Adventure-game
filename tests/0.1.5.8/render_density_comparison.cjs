// Reproducible software preview of runtime-prepared textures and unchanged world
// rectangles. This is not a native GPU screenshot; the companion .gd can capture
// one when WindowServer is available.
const fs=require('fs'),path=require('path');
const sharp=require('/Users/jasonsmacair/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const dir=path.join(__dirname,'density-renders');
const meta=JSON.parse(fs.readFileSync(path.join(dir,'density-metadata.json'),'utf8')).objects;
const placements=[['cabin',151,310],['prop_1',292,323],['bench',265,230],['tree_0',38,405],['tree_2',524,463],['shrub_2',453,388],['ore_0',402,334],['stump_0',312,447],['resource_branch_0',203,393],['resource_branch_1',246,417],['resource_rock_0',376,425],['resource_rock_1',391,453],['resource_rope_0',164,450],['resource_rope_1',174,400]];
const bitmap=(key,state)=>'data:image/png;base64,'+fs.readFileSync(path.join(dir,`${key}-${state}.png`)).toString('base64');
const image=(key,state,x,y,w,h)=>`<image href="${bitmap(key,state)}" x="${x}" y="${y}" width="${w}" height="${h}" preserveAspectRatio="none"/>`;
function panel(state,offset){
 let content=image('meadow',state,-170,-430,2200,1500)+image('pond_1',state,350,12,220,150);
 for(const [key,x,y]of placements){const m=meta[key],scale=m.world[1]/m.source[1];content+=image(key,state,x-m.anchor[0]*scale,y-m.anchor[1]*scale,...m.world);}
 return `<svg x="${offset}" y="82" width="590" height="480" viewBox="0 0 590 480" overflow="hidden">${content}</svg><rect x="${offset}" y="82" width="590" height="480" stroke="#395944" fill="none"/>`;
}
const text=(x,y,content,size=18,color='#e6dfc7')=>`<text x="${x}" y="${y}" font-size="${size}" fill="${color}" font-family="Arial,sans-serif">${content}</text>`;
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1246" height="670"><rect width="1246" height="670" fill="#14251f"/>${text(22,33,'Actual game sprites · same physical sizes · shared 2 world units per texel',21)}${text(22,67,'BEFORE · source grain varies by object',19)}${text(636,67,'AFTER · strokes share the ground sampling scale',19)}${panel('before',22)}${panel('after',636)}${text(22,590,'Cabin 222 world high: 498 → 111 texels     Workbench 82: 378 → 41 texels')}${text(22,619,'Branches / grass 38 world high: 257–336 → 19 texels     Meadow 2200 × 1500: 1100 × 750 texels')}${text(22,648,'Software preview of runtime textures. Original world rectangles and foot anchors stay unchanged.',16,'#a9c2a9')}</svg>`;
fs.writeFileSync(path.join(dir,'paint-density-before-after.svg'),svg);
sharp(Buffer.from(svg)).png().toFile(path.join(dir,'paint-density-before-after.png')).then(()=>console.log('PAINT_DENSITY_SOFTWARE_PREVIEW_SAVED 1246x670 world_scale=1:1')).catch(error=>{console.error(error);process.exitCode=1});
