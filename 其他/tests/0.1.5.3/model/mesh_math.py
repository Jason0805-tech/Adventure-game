"""Render a single rigged, textured 3D traveler into fixed-registration 2D atlases.
This is a mesh renderer, not a deformation of previously drawn sprite legs.
The same right-hand joint and camera are used for every heading and weapon.
"""
from pathlib import Path
import json, math, struct, time
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
ASSETS=ROOT/'output/adventure game 0.1.5.3/assets'
MODEL=Path(__file__).parent
W,H,SS=96,160,2
ANGLES=[0,30,45,60,90,120,135,150,180,210,225,240,270,300,315,330]
BASE=np.array([[.76,.52,.14],[.10,.35,.40],[.30,.41,.20],[.12,.29,.29],[.35,.23,.15],[.83,.56,.40],[.12,.18,.15],[.59,.60,.53],[.68,.40,.21],[.10,.24,.21]],dtype=float)
TEX=None
if (ASSETS/'paint-materials.png').exists():
 raw=np.asarray(Image.open(ASSETS/'paint-materials.png').convert('RGB'),dtype=float)/255
 hh,ww=raw.shape[:2]
 TEX=[]
 for i in range(6):
  tile=raw[int((i//3)*hh/2):int((i//3+1)*hh/2),int((i%3)*ww/3):int((i%3+1)*ww/3)]
  TEX.append(np.clip(tile/(tile.mean(axis=(0,1))+1e-6),.80,1.20))

def sphere(out,center,radius,mat,segments=12,rings=7,hemi=False):
 center=np.array(center);radius=np.array(radius)
 end=math.pi/2 if hemi else math.pi
 v=[];uv=[]
 for j in range(rings+1):
  a=end*j/rings
  for i in range(segments+1):
   b=math.tau*i/segments
   v.append(center+radius*np.array([math.sin(a)*math.cos(b),math.cos(a),math.sin(a)*math.sin(b)]))
   uv.append([i/segments,j/rings])
 v=np.array(v);uv=np.array(uv)
 for j in range(rings):
  for i in range(segments):
   a=j*(segments+1)+i;b=a+segments+1
   for ids in [[a,b,a+1],[a+1,b,b+1]]:out.append((v[ids],uv[ids],mat))

def tube(out,a,b,radius,mat,segments=10):
 a=np.array(a);b=np.array(b);axis=b-a;axis=axis/np.linalg.norm(axis)
 ref=np.array([1.,0,0]) if abs(axis[0])<.8 else np.array([0.,1,0])
 u=np.cross(axis,ref);u/=np.linalg.norm(u);v=np.cross(axis,u)
 ends=[]
 for p in [a,b]:
  ends.append(np.array([p+radius*(u*math.cos(math.tau*i/segments)+v*math.sin(math.tau*i/segments)) for i in range(segments)]))
 for i in range(segments):
  k=(i+1)%segments
  uv=np.array([[i/segments,0],[i/segments,1],[(i+1)/segments,0]])
  out.append((np.array([ends[0][i],ends[1][i],ends[0][k]]),uv,mat))
  out.append((np.array([ends[0][k],ends[1][i],ends[1][k]]),np.array([[(i+1)/segments,0],[i/segments,1],[(i+1)/segments,1]]),mat))
  for j in range(2):out.append((np.array([[a,b][j],ends[j][i],ends[j][k]]),np.array([[.5,.5],[0,0],[1,1]]),mat))

def coat(out,bob):
 y=[.69,.82,1.08,1.39,1.46];rx=[.29,.34,.33,.27,.20];rz=[.19,.23,.22,.17,.12];n=14
 verts=[]
 for j in range(len(y)):
  verts.append(np.array([[rx[j]*math.cos(math.tau*i/n),y[j]+bob,rz[j]*math.sin(math.tau*i/n)] for i in range(n)]))
 for j in range(4):
  for i in range(n):
   k=(i+1)%n
   out.append((np.array([verts[j][i],verts[j+1][i],verts[j][k]]),np.array([[i/n,j/4],[i/n,(j+1)/4],[(i+1)/n,j/4]]),0))
   out.append((np.array([verts[j][k],verts[j+1][i],verts[j+1][k]]),np.array([[(i+1)/n,j/4],[i/n,(j+1)/4],[(i+1)/n,(j+1)/4]]),0))
 sphere(out,[0,1.46+bob,0],[.20,.06,.12],0,10,4)
 # Slim front opening and collar, painted rather than a shiny zipper.
 tube(out,[0,.74+bob,.236],[0,1.33+bob,.20],.017,3,6)

def foot_cycle(t):
 t=t%1
 if t<.5:return .30-1.20*t,0.
 q=(t-.5)*2
 return -.30*math.cos(math.pi*q),.10*math.sin(math.pi*q)

def knee(hip,ankle,l1=.38,l2=.38):
 delta=ankle-hip;d=np.linalg.norm(delta);direction=delta/d
 d=min(d,l1+l2-.002)
 along=(l1*l1-l2*l2+d*d)/(2*d)
 bend=np.array([0.,0,1.]);bend-=direction*np.dot(bend,direction);bend/=np.linalg.norm(bend)
 return hip+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))

def pose(frame,armed=False):
 out=[];t=frame/8 if frame<8 else 0;active=frame<8
 bob=-.025*math.cos(t*math.tau*2) if active else 0
 # Legs are solved in anatomical sagittal planes, fixed lengths and knee direction.
 for i,side in enumerate([-1,1]):
  z,lift=foot_cycle(t+i*.5) if active else (0.,0.)
  hip=np.array([side*.14,.85+bob,0.])
  ankle=np.array([side*.14,.13+lift,z])
  joint=knee(hip,ankle)
  tube(out,hip,joint,.079,3);sphere(out,joint,[.082,.082,.082],3,8,4)
  tube(out,joint,ankle,.076,3)
  sphere(out,ankle+np.array([0,-.035,.055]),[.115,.09,.16],4,10,5)
  sphere(out,ankle+np.array([0,-.105,.06]),[.119,.018,.161],6,10,3)
 body_start=len(out)
 coat(out,bob)
 # Pack and rolled blanket are behind the body for every angle.
 sphere(out,[0,1.09+bob,-.295],[.28,.34,.155],2)
 tube(out,[-.255,1.42+bob,-.315],[.255,1.42+bob,-.315],.105,2,12)
 tube(out,[-.265,1.42+bob,-.335],[.265,1.42+bob,-.335],.055,9,10)
 for side in [-1,1]:
  tube(out,[side*.185,1.40+bob,.154],[side*.226,.88+bob,.211],.024,2,8)
 for side in [-1,1]:
  swing=-math.sin(t*math.tau)*.065*side if active else 0
  shoulder=np.array([side*.287,1.36+bob,0])
  elbow=np.array([side*.385,1.105+bob,.035+swing])
  hand=np.array([side*.378,.895+bob,.16+swing])
  if side==-1 and armed:
   elbow=np.array([-.383,1.135+bob,.08+swing*.35])
   hand=np.array([-.376,.955+bob,.25+swing*.35])
  tube(out,shoulder,elbow,.093,0);sphere(out,elbow,[.095,.10,.095],0,8,4)
  tube(out,elbow,hand,.083,0);sphere(out,hand,[.073,.077,.076],5,10,5)
  if side==-1:grip=hand.copy()
 # Stable head and low-detail face.
 sphere(out,[0,1.755+bob,.025],[.31,.31,.272],5,14,8)
 for side in [-1,1]:
  sphere(out,[side*.303,1.766+bob,.009],[.057,.070,.050],5,8,4)
  sphere(out,[side*.12,1.795+bob,.276],[.016,.023,.012],6,8,4)
  sphere(out,[side*.247,1.913+bob,.148],[.070,.047,.045],8,8,4)
 sphere(out,[0,1.742+bob,.299],[.032,.025,.023],5,8,4)
 # Hat dome, folded brim and pompom.
 sphere(out,[0,1.919+bob,.002],[.349,.257,.306],1,14,8,True)
 sphere(out,[0,1.943+bob,.008],[.354,.064,.318],1,14,5)
 sphere(out,[0,2.24+bob,-.012],[.096,.099,.098],0,10,6)
 for vertices,uv,mat in out[body_start:]:vertices[:,1]+=.19
 grip[1]+=.19
 return out,grip

def box(out,center,size,mat):
 c=np.array(center);s=np.array(size)/2
 v=np.array([c+s*np.array([x,y,z]) for x in [-1,1] for y in [-1,1] for z in [-1,1]])
 for ids in [[0,1,3,2],[4,6,7,5],[0,4,5,1],[2,3,7,6],[0,2,6,4],[1,5,7,3]]:
  for tri in [[0,1,2],[0,2,3]]:out.append((v[np.array(ids)[tri]],np.array([[0,0],[1,0],[1,1]]),mat))

def weapon(grip,index):
 out=[];axis=np.array([0.,.985,.172]);right=np.array([1.,0,0.]);normal=np.cross(right,axis)
 length=[.55,.24,.43,.24,.46,.59][index]
 tube(out,grip-axis*.095,grip+axis*.10,.025,4,8)
 if index==2:
  tube(out,grip-axis*.12,grip+axis*length,.027,8,8)
  box(out,grip+axis*(length-.06),[.26,.12,.065],7)
 else:
  start=grip+axis*.08;end=start+axis*length
  tube(out,start-right*.083,start+right*.083,.022,8,8)
  width=[.065,.047,0,.047,.06,.071][index]
  mat=8 if index in [3,4] else 7
  vs=[start-right*width,start+right*width,end-right*width*.45,end+right*width*.45,end+axis*.105]
  # Two bevel surfaces and a narrower tip; no glitter or unrealistic glow.
  edge1=np.array([vs[0],vs[1],vs[3],vs[2]])
  for off in [-.018,.018]:
   vv=edge1+normal*off
   for ids in [[0,1,2],[0,2,3]]:out.append((vv[ids],np.array([[0,0],[1,0],[1,1]]),mat))
   out.append((np.array([vs[2],vs[3],vs[4]])+normal*off,np.array([[0,0],[1,0],[.5,1]]),mat))
  # Connect the bevel faces into a closed blade volume. A side-view sword
  # must remain visible rather than disappear as a zero-thickness plane.
  outline=[vs[0],vs[1],vs[3],vs[4],vs[2]]
  for i in range(len(outline)):
   a=outline[i];b=outline[(i+1)%len(outline)]
   edge=np.array([a-normal*.018,b-normal*.018,b+normal*.018,a+normal*.018])
   for ids in [[0,1,2],[0,2,3]]:
    out.append((edge[ids],np.array([[0,0],[1,0],[1,1]]),mat))
 return out

TILT=math.radians(23)
SCALE=42.0
LIGHT=np.array([-.45,.75,.48]);LIGHT/=np.linalg.norm(LIGHT)
def rotation(angle):
 a=math.radians(angle);c=math.cos(a);s=math.sin(a)
 return np.array([[c,0,s],[0,1,0],[-s,0,c]])

def project(v):
 return np.column_stack([W*.5+v[:,0]*SCALE,H-26-(v[:,1]*math.cos(TILT)-v[:,2]*math.sin(TILT))*SCALE]),v[:,2]*math.cos(TILT)+v[:,1]*math.sin(TILT)

def render(mesh,yaw,depth=None):
 ww,hh=W*SS,H*SS
 img=np.zeros((hh,ww,4),dtype=np.uint8)
 zbuf=np.full((hh,ww),-np.inf) if depth is None else depth.copy()
 r=rotation(yaw)
 for vertices,uv,mat in mesh:
  v=vertices@r.T
  xy,z=project(v);xy*=SS
  xmin=max(0,int(np.floor(xy[:,0].min())));xmax=min(ww-1,int(np.ceil(xy[:,0].max())))
  ymin=max(0,int(np.floor(xy[:,1].min())));ymax=min(hh-1,int(np.ceil(xy[:,1].max())))
  if xmin>xmax or ymin>ymax:continue
  a,b,c=xy
  den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-8:continue
  yy,xx=np.mgrid[ymin:ymax+1,xmin:xmax+1];xx=xx+.5;yy=yy+.5
  w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
  w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den
  w2=1-w0-w1
  zz=w0*z[0]+w1*z[1]+w2*z[2]
  old=zbuf[ymin:ymax+1,xmin:xmax+1]
  mask=(w0>=-1e-7)&(w1>=-1e-7)&(w2>=-1e-7)&(zz>old+1e-7)
  if not mask.any():continue
  normal=np.cross(v[1]-v[0],v[2]-v[0]);normal/=np.linalg.norm(normal)+1e-10
  # Flat diffuse lighting quantized gently to broad painterly tonal masses.
  bright=1.0 # Painted 2D palette: no directional surface shading.
  cols=np.broadcast_to(BASE[mat]*bright,(*w0.shape,3)).copy()
  if TEX is not None and (mat<6 or mat in [7,8]):
   tu=w0*uv[0,0]+w1*uv[1,0]+w2*uv[2,0];tv=w0*uv[0,1]+w1*uv[1,1]+w2*uv[2,1]
   tile=TEX[mat if mat<6 else 4];h,w=tile.shape[:2]
   cols*=tile[np.clip((tv*(h-1)).astype(int),0,h-1),np.clip((tu*(w-1)).astype(int),0,w-1)]
  target=img[ymin:ymax+1,xmin:xmax+1]
  target[mask,:3]=(np.clip(cols[mask],0,1)*255).astype(np.uint8);target[mask,3]=255
  old[mask]=zz[mask]
 return Image.fromarray(img).resize((W,H),Image.Resampling.LANCZOS),zbuf

def export_gltf(mesh):
 # An actual 3D mesh reference accompanies the game; same geometry as atlases.
 points=np.concatenate([x[0] for x in mesh]).astype('<f4')
 colors=np.concatenate([np.tile(np.r_[BASE[x[2]],1.],(3,1)) for x in mesh]).astype('<f4')
 raw=points.tobytes()+colors.tobytes()
 (MODEL/'traveler-reference.bin').write_bytes(raw)
 gltf={'asset':{'version':'2.0','generator':'Forest Wanderer shared anatomical rig'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':'Right-handed traveler reference'}], 'meshes':[{'primitives':[{'attributes':{'POSITION':0,'COLOR_0':1},'material':0}]}], 'materials':[{'doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':1}}], 'buffers':[{'uri':'traveler-reference.bin','byteLength':len(raw)}], 'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':points.nbytes},{'buffer':0,'byteOffset':points.nbytes,'byteLength':colors.nbytes}], 'accessors':[{'bufferView':0,'componentType':5126,'count':len(points),'type':'VEC3','min':points.min(axis=0).tolist(),'max':points.max(axis=0).tolist()},{'bufferView':1,'componentType':5126,'count':len(colors),'type':'VEC4'}]}
 (MODEL/'traveler-reference.gltf').write_text(json.dumps(gltf,indent=2))

def main():
 start=time.time()
 ASSETS.mkdir(exist_ok=True)
 atlas_u=Image.new('RGBA',(W*len(ANGLES),H*9));atlas_a=Image.new('RGBA',(W*len(ANGLES),H*9))
 weapons=[Image.new('RGBA',(W*len(ANGLES),H*9)) for _ in range(6)]
 info={'columns':len(ANGLES),'angles':ANGLES,'rows':9,'walk_frames':8,'idle_frame':8,'cell':[W,H],'anchor':[W/2,H-14],'local_right_hand':'negative local X is anatomical right for a +Z-facing model; never mirrored','frames':[]}
 for frame in range(9):
  m_u,_=pose(frame,False);m_a,grip=pose(frame,True)
  if frame==8:export_gltf(m_a+weapon(grip,0))
  for direction,yaw in enumerate(ANGLES):
   unarmed,_=render(m_u,yaw);armed,depth=render(m_a,yaw)
   loc=(direction*W,frame*H);atlas_u.paste(unarmed,loc);atlas_a.paste(armed,loc)
   hand,hand_depth=project((grip@rotation(yaw).T).reshape(1,3))
   info['frames'].append({'direction':direction,'angle':yaw,'frame':frame,'right_hand':hand[0].tolist(),'hand_depth':float(hand_depth[0]),'grip_3d':grip.tolist()})
   for i in range(6):
    wi,_=render(weapon(grip,i),yaw,depth)
    weapons[i].paste(wi,loc)
  print('RENDERED pose',frame,'elapsed',round(time.time()-start,1),flush=True)
 atlas_u.save(ASSETS/'traveler-unarmed-directions.png');atlas_a.save(ASSETS/'traveler-armed-directions.png')
 for i,a in enumerate(weapons):a.save(ASSETS/('held-weapon-%d.png'%i))
 (ASSETS/'traveler-directions.json').write_text(json.dumps(info,indent=2))
 (MODEL/'render-report.json').write_text(json.dumps({'seconds':time.time()-start,'headings':len(ANGLES),'walk_frames':8,'idle_frames':1,'weapons':6,'right_hand_shared':True},indent=2))
 print('AVATAR_RENDER_COMPLETE',flush=True)
if __name__=='__main__':main()
