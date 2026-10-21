"""Source-paint registration only. Never modifies the original atlas pixels."""
import json,math
from pathlib import Path
P=Path(__file__).parent
old=json.load(open(P.parents[1]/'0.1.6.1/art-revision/source_legs.json'))['species']['wolf']['2']
phases={'front_left':0,'front_right':.5,'hind_right':.25,'hind_left':.75}
def hull(points):
 points=sorted(set(tuple(p)for p in points))
 def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
 lo=[];hi=[]
 for p in points:
  while len(lo)>1 and cross(lo[-2],lo[-1],p)<=0:lo.pop()
  lo.append(p)
 for p in reversed(points):
  while len(hi)>1 and cross(hi[-2],hi[-1],p)<=0:hi.pop()
  hi.append(p)
 return [list(p)for p in lo[:-1]+hi[:-1]]
def leg(name,root,knee,ankle,paw,width=16,mask=None):
 if mask is None:
  points=[]
  for center,radius in [(root,width),(knee,width*.9),(ankle,width*.85)]:
   for j in range(8):points.append([round(center[0]+math.cos(j*math.tau/8)*radius,3),round(center[1]+math.sin(j*math.tau/8)*radius,3)])
  points += [[paw[0],paw[1]],[paw[2],paw[1]],[paw[2],paw[3]],[paw[0],paw[3]]]
  mask=hull(points)
 return dict(name=name,root=root,knee=knee,ankle=ankle,paw_mask=[[paw[0],paw[1]],[paw[2],paw[1]],[paw[2],paw[3]],[paw[0],paw[3]]],mask=mask,phase=phases[name],reach=12,lift=6)
D={
0:dict(direction=0,legs=[
 leg('front_left',[177,246],[177,274],[180,298],[161,283,197,313],16),
 leg('front_right',[206,245],[205,277],[206,310],[189,292,225,325],16)]),
1:dict(direction=1,legs=[
 leg('hind_right',[145,239],[138,268],[133,288],[116,273,152,307],17,[[130,230],[160,232],[163,253],[152,274],[152,300],[119,308],[112,290],[121,270],[125,249]]),
 leg('front_left',[184,241],[187,266],[185,279],[166,263,205,295],16),
 leg('front_right',[225,240],[229,273],[230,307],[211,290,250,325],18)]),
2:old,
3:dict(direction=3,legs=[
 leg('hind_right',[149,246],[145,278],[143,306],[126,291,161,324],16,[[136,233],[166,237],[168,259],[161,286],[162,321],[127,325],[119,307],[126,280],[131,259]]),
 leg('front_left',[178,239],[179,264],[176,280],[160,266,193,296],14),
 leg('front_right',[218,238],[215,271],[218,301],[201,286,238,319],17)]),
4:dict(direction=4,legs=[
 leg('hind_right',[167,242],[166,274],[163,305],[147,288,180,322],15,[[151,231],[177,234],[178,270],[177,286],[179,321],[146,325],[141,306],[149,278]]),
 leg('hind_left',[217,240],[215,271],[215,302],[199,285,233,321],15,[[205,230],[232,231],[235,264],[231,282],[234,322],[199,322],[201,292],[204,271]])]),
5:dict(direction=5,legs=[
 leg('front_right',[159,242],[151,270],[146,300],[127,284,164,319],16),
 leg('hind_left',[208,247],[212,270],[211,291],[194,278,229,308],15),
 leg('hind_right',[229,248],[229,277],[227,309],[208,291,246,326],18,[[214,235],[241,237],[245,261],[245,280],[247,325],[210,328],[206,309],[213,280]])]),
6:dict(direction=6,legs=[
 leg('front_left',[127,239],[112,271],[98,305],[80,290,116,323],16),
 leg('front_right',[147,240],[143,276],[141,309],[124,294,160,326],16),
 leg('hind_left',[207,239],[216,271],[203,299],[187,283,222,316],15),
 leg('hind_right',[243,240],[243,273],[245,308],[227,291,265,326],17)]),
7:dict(direction=7,legs=[
 leg('front_right',[164,243],[163,276],[161,309],[143,291,181,326],17),
 leg('front_left',[200,241],[201,266],[201,280],[184,264,220,296],15),
 leg('hind_right',[248,247],[252,274],[252,295],[235,281,271,313],16)])}
# Anatomical names of source-key E regions.
rename={'front_near':'front_right','front_far':'front_left','hind_near':'hind_right','hind_far':'hind_left'}
for d,definition in D.items():
 a=math.radians(d*45)
 for x in definition['legs']:
  x['name']=rename.get(x['name'],x['name']);x['phase']=phases[x['name']]
  x['forward']=[round(math.sin(a),8),round(math.cos(a)*.30,8)]
  x.setdefault('reach',12);x.setdefault('lift',6)
 definition['source_frame']=0
result={'format':'native-frame-zero-skin-v1','cell':[384,384],'species':{'wolf':{str(k):v for k,v in D.items()}},'provenance':'Hand-authored source bones and native-paint guard polygons. Original PNG unchanged; no synthetic limb shapes.'}
(P/'source-legs-wolf.json').write_text(json.dumps(result,indent=2)+'\n')
print('WOLF_SOURCE_SKIN_READY',len(D),sum(len(v['legs'])for v in D.values()))
