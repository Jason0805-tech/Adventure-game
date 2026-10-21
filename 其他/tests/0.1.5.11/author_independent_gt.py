"""Manual ground-plane landmarks, authored from native visible artwork only.
No collision profile JSON is opened by this script. Do not replace these with
polygon centroids: that would prove only what the collider author already drew.
"""
import json
from pathlib import Path
BASE=Path(__file__).resolve().parent
SRC=BASE.parent/'0.1.5.7'/'profile-sprites'
META=json.loads((SRC/'sprite-metadata.json').read_text())
samples=[]
def point(profile,part,xy,expect='solid',capsule=True):
 m=META[profile.replace('_rocks','')];w=m['width'];h=m['height']
 samples.append(dict(profile=profile,part=part,source_px=xy,source_size=[w,h],uv=[xy[0]/w,xy[1]/h],expect=expect,capsule_clear=capsule))
def uvpoint(profile,part,uv,expect='solid',capsule=True):
 m=META[profile];point(profile,part,[uv[0]*m['width'],uv[1]*m['height']],expect,capsule)
# Trunks at their grounded flares; same apparent wood up above is projected
# overhead, and must not create a wall merely because the sprite is opaque.
for i,base,upper in [(0,(250,483),(283,250)),(1,(226,475),(204,345)),(2,(190,485),(254,170)),(3,(225,387),(235,223)),(4,(155,460),(164,300)),(5,(224,460),(203,174))]:
 point(f'tree_{i}','grounded_trunk_root',[(270,445),(225,430),(195,440),(218,350),(150,440),(232,438)][i])
 if i!=4:point(f'tree_{i}','low_foliage_in_front_of_root',base,'free',False)
 point(f'tree_{i}','elevated_bark_or_fork',upper,'free')
 uvpoint(f'tree_{i}','upper_leaf_canopy',(.65,.22),'free')
for i in range(4):
 uvpoint(f'shrub_{i}','root_core',(.51,.81))
 uvpoint(f'shrub_{i}','elevated_leaf_spread',(.48,.20),'free')
for profile in ['cabin','prop_0']:
 point(profile,'closed_door_ground_volume',(368,367))
 point(profile,'left_wall_ground_volume',(175,359))
 point(profile,'front_step_ground_volume',(427,446))
 point(profile,'lowest_step_front',(396,460))
 point(profile,'ground_below_oblique_step',(396,480),'free',False)
 point(profile,'elevated_chimney',(158,40),'free')
 point(profile,'elevated_roof',(297,174),'free')
# Arch picture has an off-center root anchor at its right masonry foot.
point('gate','left_masonry_foot',(91,284))
point('gate','right_masonry_foot',(348,334))
point('gate','opening_center',(235,240),'free')
point('gate','overhead_lintel',(230,55),'free')
for i in range(1,6):
 uvpoint(f'prop_{i}','lower_solid_body',(.51,.75))
 uvpoint(f'prop_{i}','upper_wood_or_lid',(.48,.18),'free')
point('bench','left_support_ground',(119,298))
point('bench','right_support_ground',(329,297))
point('bench','lower_crossbrace',(241,294))
point('bench','elevated_tools_tabletop',(239,166),'free')
point('bench','elevated_rear_post',(108,77),'free')
for i in range(2):
 uvpoint(f'stump_{i}','lower_wood_root',(.51,.79))
 uvpoint(f'stump_{i}','elevated_cut_face',(.51,.20),'free')
for i in range(3):
 uvpoint(f'ore_{i}','main_boulder_ground',(.60,.76))
 uvpoint(f'ore_{i}','foreground_boulder_ground',(.28,.80))
 uvpoint(f'ore_{i}','elevated_peak',(.55,.15),'free')
for kind in ['branch','rock','rope']:
 for state in ['', '_spent']:
  for i in range(3):
   name=f'resource_{kind}{state}_{i}'
   expect='solid' if kind=='rock' and not state else 'free'
   uvpoint(name,'small_rock_ground' if expect=='solid' else 'soft_collectible_or_remnant',(.50,.75),expect)
# Every visible gray shoreline stone has a separate independently selected
# lower-ground landmark, including the five small stones in/on water.
rocks=[[(205,83),(454,136),(403,102),(88,152),(98,320),(221,360),(397,369)],[(209,90),(453,130),(64,257),(126,335),(214,356)],[(402,215),(314,368),(94,315),(321,178),(369,241)]]
for i,items in enumerate(rocks):
 for j,xy in enumerate(items):point(f'pond_{i}_rocks',f'shore_stone_{j}_ground',xy)
 point(f'pond_{i}','water_center',[(280,200),(300,215),(235,210)][i])
 point(f'pond_{i}','upper_reeds_on_passable_land',[(302,15),(280,15),(330,12)][i],'free')
BASE.joinpath('independent-ground-landmarks.json').write_text(json.dumps({'version':'0.1.5.11','method':'Native source-art points manually selected before reading or executing new collision contours. Physical expectation is top-down ground volume, not opaque visual silhouette. Tall upper wood/roof/table/arch pixels are explicitly negative tests. All 48 exported profiles, all 17 shoreline stones. Current field branch/fiber and spent nodes intentionally soft. Actor-capsule-free assertions are separate from source center coverage. Initial five root points were found on low foliage after independent 4x source inspection; retained as center-negative, with new bare-wood points added. Initial failed report is preserved.','samples':samples},indent=2))
print('INDEPENDENT_GT',len(samples),'landmarks',len(set(s['profile'] for s in samples)),'profiles')
