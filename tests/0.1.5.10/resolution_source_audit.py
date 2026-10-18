from pathlib import Path
import struct,json
root=Path('/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech')
release=root/'output/adventure game 0.1.5.9'
out=root/'tests/0.1.5.10'
assets=[]
for p in sorted((release/'assets').glob('*.png')):
    raw=p.read_bytes()[:24]
    assert raw[:8]==b'\x89PNG\r\n\x1a\n'
    w,h=struct.unpack('>II',raw[16:24])
    assets.append({'path':str(p.relative_to(release)),'source_size':[w,h],'source_pixel_count':w*h})
old=json.loads((root/'tests/0.1.5.9/actual-paint-density-results.json').read_text())
models=[]
for record in old['sampling']:
    sw,sh=record['source_size'];ww,wh=record['world_size'];dw,dh=record['display_size']
    models.append({**record,'native_texels_per_world_unit':[sw/ww,sh/wh],'old_display_texels_per_world_unit':[dw/ww,dh/wh], 'linear_resolution_recovery_if_restore_source':[sw/dw,sh/dh], 'texel_count_recovery_if_restore_source':sw*sh/(dw*dh)})
result={
    'source_release':'0.1.5.9',
    'method':'Read PNG IHDR and validated runtime crop/display measurements from tests/0.1.5.9/actual-paint-density-results.json. No asset or runtime modification.',
    'native_avatar':{'cell':[96,160],'scale':0.8,'display_world_size':[76.8,128.0],'native_texels_per_world_unit':1.25},
    'native_npc':{'cell':[96,160],'atlas_size':[768,1440],'directions':8,'walk_frames':9},
    'meadow_bottleneck':{'source_size':[1518,1036],'world_size':[2200,1500],'native_texels_per_world_unit':[1518/2200,1036/1500],'old_display_size':[1100,750],'target_2x_retina_raster_size':[4400,3000],'target_avatar_density_raster_size':[2750,1875],'warning':'Larger file dimensions produced by interpolation add no original painted detail. Fresh higher-resolution painting or controlled painted-detail synthesis is necessary for actual extra background detail.'},
    'assets':assets,'runtime_static_sampling':models,
    'recommendation':['Remove .9 unconditional2world-unitstexel reduction; use originalfullresolutionRGBA and mipmaps.','Keep originalsourcegeometry/footanchors/UVs, playeranimation and toolgrip unchanged.','Improve ground atnativepainterlydetail level; output highresolution with honest resampling disclosure.','Avoidhighfrequencyphotorealgrain; largerpainterlycolorstrokesareanartdirectionissue separatefrompixelcount.','allow_hidpi defaults true; canvas_items stretch defaults/currently enabled. 2DMSAA smoothsgeometryedgesonly, notrasterdetail.','Prepareground mipmaps fromthehigherqualityground; do not cacheallscenery at2worldunits/texel.']
}
(out/'source-resolution-audit.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print('SOURCE_RESOLUTION_AUDIT',len(assets),'PNG files',len(models),'runtime model-size records')
