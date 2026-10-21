"""Author native 2D animal body/leg registration. PNG paint is never altered.
The body polygon clips away the obsolete independently generated legs at draw time.
New articulated pigment limbs are Canvas geometry, like the approved traveler rig.
"""
from pathlib import Path
import json,re,math
ROOT=Path(__file__).resolve().parents[3]
P=ROOT/'output/adventure game 0.1.6.1/assets/animal_atlas.json'
d=json.loads(P.read_text())
# Each lower contour is left to right, in original 384px registered cells.
# Points follow the belly, chest, tail and rump rather than one horizontal crop.
contours={
'wolf':[
[(0,245),(149,245),(159,242),(173,248),(192,252),(215,245),(230,241),(384,241)],
[(0,280),(90,280),(124,263),(146,234),(173,242),(190,249),(214,245),(242,238),(268,236),(384,236)],
[(0,285),(76,279),(102,265),(124,240),(149,230),(174,236),(196,247),(219,248),(241,240),(261,232),(384,232)],
[(0,292),(87,287),(121,270),(150,245),(171,242),(194,256),(213,243),(235,238),(384,238)],
[(0,253),(158,250),(173,242),(178,280),(187,308),(196,320),(204,293),(207,256),(221,244),(384,244)],
[(0,245),(151,243),(170,245),(187,258),(210,244),(230,258),(255,278),(291,287),(384,287)],
[(0,235),(126,235),(145,243),(169,249),(194,238),(221,237),(245,248),(267,264),(296,277),(384,277)],
[(0,242),(143,242),(164,244),(184,249),(210,242),(229,244),(250,261),(276,267),(384,267)]],
'deer':[
[(0,244),(155,244),(172,253),(198,254),(213,247),(384,247)],
[(0,241),(117,240),(146,236),(171,240),(194,249),(211,251),(238,239),(384,239)],
[(0,245),(116,241),(143,241),(165,248),(193,251),(217,247),(233,232),(384,232)],
[(0,246),(121,239),(151,237),(177,246),(202,245),(228,234),(384,234)],
[(0,244),(164,244),(179,253),(200,254),(216,246),(384,246)],
[(0,239),(156,236),(177,242),(194,247),(213,240),(237,236),(269,245),(384,245)],
[(0,235),(151,235),(172,244),(193,249),(220,247),(248,241),(271,245),(384,245)],
[(0,243),(156,242),(179,251),(200,249),(219,240),(246,236),(270,243),(384,243)]],
'fox':[
[(0,292),(143,291),(159,271),(178,276),(193,280),(214,272),(231,264),(384,264)],
[(0,245),(138,245),(160,250),(180,262),(200,274),(218,267),(242,257),(384,257)],
[(0,288),(114,286),(137,272),(155,259),(179,269),(199,272),(220,263),(241,253),(384,253)],
[(0,311),(134,308),(154,293),(177,272),(197,274),(216,266),(236,256),(384,256)],
[(0,264),(160,264),(174,272),(184,294),(197,314),(210,301),(222,274),(238,264),(384,264)],
[(0,263),(148,262),(170,266),(188,271),(209,275),(225,290),(248,301),(275,300),(384,300)],
[(0,253),(142,253),(164,268),(188,270),(210,267),(233,270),(256,283),(283,291),(384,291)],
[(0,265),(151,265),(173,274),(196,279),(213,266),(235,266),(255,278),(280,281),(384,281)]],
'bear':[
[(0,259),(132,259),(152,266),(175,277),(198,269),(223,265),(253,253),(384,253)],
[(0,269),(113,268),(139,265),(165,274),(191,281),(216,267),(242,269),(266,257),(384,257)],
[(0,273),(99,272),(121,275),(145,278),(173,268),(197,269),(223,275),(249,267),(270,250),(384,250)],
[(0,269),(106,267),(133,270),(164,275),(192,269),(217,264),(243,254),(384,254)],
[(0,265),(135,265),(158,271),(181,278),(208,273),(229,264),(384,264)],
[(0,255),(151,255),(174,266),(196,276),(222,272),(244,268),(270,263),(384,263)],
[(0,252),(129,251),(151,267),(174,275),(196,273),(219,267),(242,274),(270,273),(384,273)],
[(0,256),(147,256),(169,269),(195,279),(219,271),(246,264),(269,264),(384,264)]],
'rabbit':[
[(0,303),(160,300),(169,292),(185,295),(204,295),(216,291),(229,301),(384,301)],
[(0,297),(145,294),(160,293),(178,298),(192,296),(204,285),(217,287),(236,291),(384,291)],
[(0,298),(139,296),(159,292),(180,297),(202,291),(218,280),(235,284),(384,284)],
[(0,300),(145,299),(166,295),(187,298),(204,289),(227,279),(245,282),(384,282)],
[(0,305),(158,303),(172,297),(180,309),(196,316),(211,309),(217,297),(234,303),(384,303)],
[(0,282),(154,282),(170,290),(187,296),(208,294),(229,298),(247,302),(384,302)],
[(0,286),(145,284),(164,281),(181,291),(202,299),(226,296),(246,300),(384,300)],
[(0,297),(147,296),(169,293),(186,298),(205,296),(226,288),(246,292),(384,292)]]}
# Anatomical front/rear shoulder centers per source heading. Side-separated
# joints are projected about these, never mirroring a pose or changing identity.
centers={
'wolf': [((191,244),(191,232)),((231,240),(153,235)),((242,239),(143,231)),((226,238),(161,248)),((192,231),(192,248)),((164,240),(223,249)),((145,239),(243,232)),((165,242),(238,241))],
'deer': [((192,248),(192,237)),((222,239),(144,236)),((222,241),(139,236)),((222,234),(150,241)),((191,237),(191,247)),((172,238),(244,240)),((159,241),(243,239)),((177,245),(242,238))],
'fox': [((193,272),(191,254)),((221,267),(163,246)),((224,261),(151,260)),((222,258),(168,273)),((192,252),(194,275)),((166,265),(224,276)),((161,266),(239,270)),((171,273),(239,266))],
'bear': [((191,262),(192,245)),((241,263),(145,260)),((236,267),(116,265)),((231,255),(143,266)),((193,245),(191,269)),((166,258),(251,265)),((153,267),(259,266)),((169,266),(248,260))],
'rabbit': [((192,290),(192,279)),((211,288),(166,279)),((217,282),(163,278)),((226,279),(168,289)),((191,280),(192,298)),((166,282),(221,291)),((161,285),(218,281)),((176,293),(226,278))]}
profiles={
'wolf': dict(stride=42,halfspan=13,drop=61,width=11,paw=13,lift=13,colors=['8a7c66','514d43','30332f']),
'deer': dict(stride=52,halfspan=10,drop=62,width=8,paw=9,lift=14,colors=['a5663d','764329','40382c']),
'fox': dict(stride=34,halfspan=9,drop=39,width=10,paw=11,lift=12,colors=['774328','4f3324','342b23']),
'bear': dict(stride=50,halfspan=15,drop=42,width=20,paw=24,lift=10,colors=['8b4c2b','683b23','482b1d']),
'rabbit': dict(stride=24,halfspan=9,drop=17,width=9,paw=12,lift=10,colors=['e5c597','efd1a3','f5d9ad'])}
eyes={
'wolf': [[[180,185],[208,184]],[[247,194]],[[259,194]],[],[],[],[[135,194]],[[160,191]]],
'bear': [[[176,213],[204,213]],[[237,220]],[[266,220]],[],[],[],[[127,220]],[[145,218]]]
}
# Ground envelopes remain unchanged. Register each paw's support interval to
# the existing per-heading capsule instead of expanding physics around new art.
data=(ROOT/'output/adventure game 0.1.6.1/wildlife_data.gd').read_text()
grounds={}
for name in profiles:
 block=data.split('"'+name+'":',1)[1].split('"habitats"',1)[0]
 raw=block.split('"ground":[',1)[1].split(']',1)[0]
 grounds[name]=[tuple(map(float,x.split(',')))for x in re.findall(r'Vector4\(([^)]+)\)',raw)]

def register_foot(leg,species,direction,scale,cfg,angle):
 cx,cy,half_width,radius=grounds[species][direction]
 half_axis=half_width-radius
 # Erode the unchanged capsule by the actual rounded paw brush radius.
 inner=max(.4,radius-leg['width']*.65*scale*1.02)
 desired_x=(leg['root'][0]-192)*scale
 desired_y=cy+(1 if leg['fore'] else -1)*math.cos(angle)*.35
 forward=(math.sin(angle),math.cos(angle)*.30)
 paw_axis=(math.sin(angle),.20)
 reach=cfg['stride']/4
 for step in range(101):
  factor=1-step*.008
  left,right=-1e9,1e9
  valid=True
  for z in [-reach*factor,reach*factor]:
   for nose in [-.20,.58]:
    ox=forward[0]*z+paw_axis[0]*cfg['paw']*nose*scale
    oy=forward[1]*z+paw_axis[1]*cfg['paw']*nose*scale
    dy=desired_y+oy-cy
    if abs(dy)>inner:valid=False;break
    extent=half_axis+math.sqrt(max(0,inner*inner-dy*dy))
    left=max(left,cx-extent-ox);right=min(right,cx+extent-ox)
   if not valid:break
  if valid and left<=right:
   base_x=max(left,min(right,desired_x))
   leg['foot']=[192+base_x/scale,320+desired_y/scale]
   leg['reach_factor']=round(factor,4)
   return
 raise ValueError('No valid contact for '+species+'/'+str(direction)+'/'+leg['name'])

for species,m in d['species'].items():
 import math
 cfg=profiles[species];rigs=[];scale=m['world_height']/m['reference_height_px']
 for i,(front,rear) in enumerate(centers[species]):
  angle=math.radians(i*45);lat=(math.cos(angle),-math.sin(angle)*.45)
  legs=[]
  for end,center in [('front',front),('hind',rear)]:
   for side in [-1,1]:
    offset=cfg['halfspan']*side
    root=[center[0]+lat[0]*offset,center[1]+lat[1]*offset]
    # Ground heights remain the same plane irrespective of shoulder height.
    # The back pair is occluded by the body in frontal/rear views.
    front_depth=9*math.cos(angle)*(1 if end=='front' else -1)
    ground_y=303+front_depth+lat[1]*side*8
    if species=='rabbit':ground_y=305+front_depth*.4+lat[1]*side*5
    foot=[root[0],ground_y]
    legs.append(dict(name=end+('_left'if side==-1 else'_right'),root=root,foot=foot,side=side,fore=end=='front',depth=foot[1],width=cfg['width']*(1 if end=='front' else 1.08)))
  for leg in legs:register_foot(leg,species,i,scale,cfg,angle)
  lower=contours[species][i]
  # A fixed native-pixel fur fringe softens the belly cut without repainting
  # or blurring the original body texture. It never changes between frames.
  fringe=[]
  for a,b in zip(lower,lower[1:]):
   count=max(1,math.ceil((b[0]-a[0])/6))
   for part in range(count):
    t=part/count;x=a[0]+(b[0]-a[0])*t;y=a[1]+(b[1]-a[1])*t
    y+=1.55*math.sin(x*.83+i*1.9)+.65*math.sin(x*2.13+i)
    fringe.append([x,y])
  fringe.append(lower[-1])
  polygon=[[0,0],[384,0]]+list(reversed(fringe))
  rigs.append(dict(body_polygon=polygon,legs=legs,eyes=eyes.get(species,[[]]*8)[i],body_frame=0))
 m['render_mode']='painted-articulated-v1'
 m['gait']={**cfg,'stride_world':cfg['stride'],'stance_fraction':.5,'body_bob_pixels':1.3 if species!='rabbit' else 8,'projection_y':.30,'directions':rigs,'description':'One identity-stable native painted body per heading. Four articulated flat pigment limbs. Forward-only continuous stance, lift and recovery driven by actual distance; no ping-pong keys.'}
 m['stride_world']=cfg['stride']
 for i,poses in enumerate(m['poses']):
  for pose in poses:pose['eyes']=eyes.get(species,[[]]*8)[i]
d['version']='0.1.6.1';d['format']='native-rgba-body-and-canvas-rig-v2'
d['frame_sequence']='Continuous actual-distance phase. Every full cycle moves forward through stance, lift, swing, touchdown; no reverse playback. Original four bitmap keys retained as source archive only.'
d['registration']='Original PNG native pixels unchanged. Fixed frame-zero painted body/heading clipped by authored Canvas belly contours; articulated native-coordinate legs use the same distance/stance/swing method as the traveler.'
P.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
print('RIG_METADATA_READY 40 direction profiles; original PNGs unchanged')
