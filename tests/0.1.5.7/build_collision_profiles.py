"""Measured crop-space contacts; generated water boundaries are traced from paint.

UVs refer to Godot's exact cropped runtime images, not source-sheet cells.
Ground contact excludes overhanging crowns, decorative flowers and shadows.
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageDraw
from collections import deque
import json, math
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'tests/0.1.5.7/profile-sprites'
OUT=ROOT/'output/adventure game 0.1.5.7/collision_profiles.json'
profiles={}
def add(key,depth,polygons,notes):
    profiles[key]={'polygons':polygons,'depth_v':depth,'notes':notes}

tree_contacts=[
 [[.399,.755],[.432,.739],[.486,.747],[.536,.727],[.567,.751],[.579,.788],[.606,.817],[.601,.851],[.631,.885],[.574,.891],[.551,.869],[.515,.882],[.467,.861],[.442,.884],[.395,.871],[.419,.833],[.405,.802]],
 [[.438,.758],[.472,.744],[.520,.755],[.540,.785],[.566,.811],[.582,.852],[.561,.868],[.535,.860],[.514,.885],[.470,.888],[.446,.866],[.412,.875],[.419,.839],[.437,.803]],
 [[.407,.756],[.438,.748],[.477,.757],[.483,.792],[.495,.820],[.507,.851],[.499,.884],[.468,.897],[.438,.888],[.405,.882],[.398,.860],[.378,.859],[.393,.828]],
 [[.418,.746],[.453,.728],[.493,.741],[.536,.719],[.568,.742],[.574,.782],[.594,.819],[.627,.852],[.615,.883],[.577,.891],[.552,.861],[.517,.884],[.469,.870],[.445,.900],[.414,.881],[.427,.838],[.411,.796]],
 [[.423,.774],[.455,.756],[.506,.762],[.533,.791],[.538,.819],[.558,.854],[.583,.889],[.560,.914],[.532,.892],[.506,.916],[.474,.907],[.448,.889],[.407,.904],[.396,.876],[.422,.835]],
 [[.479,.766],[.511,.755],[.548,.762],[.568,.793],[.567,.831],[.585,.864],[.611,.889],[.589,.910],[.553,.900],[.531,.915],[.494,.906],[.471,.917],[.455,.892],[.469,.853],[.469,.812]]]
for i,poly in enumerate(tree_contacts):
    add(f'tree_{i}',max(p[1] for p in poly),[poly],f'Measured woody trunk and exposed root contact for tree variant {i}; canopy and surrounding flowers remain passable. Mirror this UV contact with the same tree draw transform.')

shrubs=[
 [[.301,.734],[.361,.707],[.447,.721],[.529,.708],[.616,.745],[.698,.773],[.727,.813],[.686,.850],[.608,.871],[.526,.864],[.455,.887],[.381,.861],[.295,.846],[.263,.798]],
 [[.219,.737],[.280,.700],[.377,.712],[.454,.694],[.548,.710],[.636,.704],[.753,.752],[.808,.791],[.772,.842],[.686,.861],[.593,.845],[.486,.883],[.397,.854],[.297,.866],[.216,.827],[.197,.783]],
 [[.266,.722],[.338,.694],[.422,.716],[.483,.691],[.587,.716],[.661,.702],[.735,.756],[.767,.806],[.722,.844],[.632,.861],[.550,.846],[.473,.875],[.405,.856],[.318,.863],[.269,.824],[.237,.777]],
 [[.273,.724],[.347,.710],[.424,.737],[.493,.703],[.564,.724],[.635,.719],[.714,.759],[.733,.811],[.700,.848],[.638,.864],[.559,.852],[.492,.884],[.416,.862],[.354,.876],[.289,.838],[.250,.783]]]
for i,poly in enumerate(shrubs):add(f'shrub_{i}',max(p[1] for p in poly),[poly],f'Distinct shrub variant {i} woody root mass; outer foliage and painted blooms are excluded.')

cabin=[[[.123,.620],[.175,.572],[.236,.555],[.330,.588],[.448,.610],[.571,.584],[.787,.516],[.865,.555],[.866,.710],[.834,.753],[.837,.815],[.755,.852],[.694,.873],[.612,.931],[.574,.915],[.555,.866],[.433,.881],[.355,.854],[.262,.821],[.192,.773],[.144,.736]]]
add('cabin',.931,cabin,'House wall foundation and protruding front steps, traced independently of roof overhang and the decorative foliage. Frontmost step defines depth.')
add('prop_0',.931,cabin,'Standalone cabin sprite shares the measured cabin foundation; intentional duplicate of cabin, not a common box.')
props={
 'prop_1':(.871,[[[.189,.590],[.258,.529],[.349,.552],[.423,.599],[.489,.664],[.580,.627],[.625,.577],[.691,.583],[.788,.618],[.813,.668],[.805,.718],[.735,.772],[.644,.795],[.610,.841],[.546,.871],[.477,.854],[.428,.819],[.363,.796],[.293,.739],[.246,.707],[.205,.661]]],'Three-log pile base following both exposed log ends and the diagonal rear timber; surrounding ground foliage excluded.'),
 'prop_2':(.847,[[[.123,.588],[.187,.546],[.270,.551],[.376,.609],[.482,.687],[.571,.637],[.629,.600],[.700,.624],[.784,.654],[.828,.702],[.844,.756],[.812,.788],[.745,.799],[.655,.801],[.605,.838],[.545,.847],[.483,.831],[.437,.805],[.338,.752],[.240,.706],[.157,.652]]],'Long log pile variant measured separately from prop_1; oblique rear log and two rounded forward ends.'),
 'prop_3':(.870,[[[.226,.730],[.283,.696],[.369,.681],[.480,.680],[.586,.690],[.681,.716],[.737,.749],[.738,.793],[.705,.821],[.634,.850],[.536,.867],[.421,.870],[.330,.852],[.259,.821],[.225,.780]]],'Barrel circular ground contact follows visible wooden lower hoop/base, ignoring upright body silhouette and plants.'),
 'prop_4':(.882,[[[.175,.681],[.243,.643],[.330,.608],[.419,.570],[.504,.564],[.592,.605],[.697,.651],[.822,.706],[.823,.755],[.743,.795],[.633,.841],[.516,.882],[.473,.865],[.377,.821],[.293,.784],[.209,.737]]],'Warm crate ground diamond; measured board base with bevelled irregular corners, separate from top surface.'),
 'prop_5':(.953,[[[.185,.674],[.247,.629],[.338,.599],[.433,.565],[.529,.552],[.625,.601],[.729,.646],[.842,.689],[.842,.744],[.763,.796],[.674,.844],[.571,.906],[.504,.953],[.459,.931],[.382,.878],[.295,.827],[.221,.774]]],'Weathered crate has narrower tall perspective; individually traced base diamond and worn front corners.')}
for k,(d,p,n) in props.items():add(k,d,p,n)
add('bench',.928,[[[.178,.733],[.224,.679],[.308,.677],[.402,.687],[.529,.679],[.668,.684],[.780,.708],[.802,.763],[.791,.818],[.785,.911],[.740,.930],[.691,.915],[.684,.838],[.343,.828],[.275,.831],[.265,.917],[.215,.928],[.173,.902],[.174,.803]]],'Workbench ground footprint, legs and lower brace. Concave front edge follows gap between feet; excludes tools, tabletop overhang and plants.')
stumps=[
 [[.111,.613],[.187,.597],[.261,.551],[.325,.587],[.443,.587],[.556,.571],[.626,.558],[.716,.611],[.813,.616],[.929,.653],[.975,.671],[.966,.718],[.876,.739],[.797,.721],[.826,.789],[.857,.902],[.820,.945],[.776,.919],[.711,.825],[.638,.802],[.548,.850],[.463,.826],[.382,.837],[.323,.908],[.264,.915],[.226,.882],[.252,.782],[.293,.704],[.184,.730],[.093,.702],[.034,.697],[.015,.659]],
 [[.224,.739],[.299,.656],[.353,.611],[.435,.615],[.503,.568],[.561,.592],[.642,.581],[.683,.646],[.742,.653],[.842,.699],[.957,.731],[.984,.771],[.972,.812],[.914,.821],[.834,.782],[.757,.772],[.792,.848],[.840,.954],[.803,.979],[.749,.954],[.693,.909],[.629,.834],[.551,.805],[.476,.828],[.385,.817],[.309,.885],[.231,.904],[.173,.873],[.170,.842]]]
for i,poly in enumerate(stumps):add(f'stump_{i}',max(p[1] for p in poly),[poly],f'Individual stump {i} exposed irregular wooden roots; passable moss/flowers omitted. Persistent solid contact after felling.')

ores=[
 [[[.382,.660],[.468,.604],[.570,.588],[.691,.606],[.799,.645],[.822,.695],[.835,.750],[.804,.794],[.746,.825],[.656,.847],[.579,.839],[.489,.866],[.418,.831],[.376,.786]],[[.144,.791],[.205,.735],[.270,.712],[.346,.733],[.420,.775],[.448,.839],[.422,.911],[.366,.953],[.293,.950],[.206,.936],[.155,.883]]],
 [[[.281,.661],[.385,.615],[.494,.604],[.629,.639],[.733,.688],[.760,.755],[.736,.797],[.676,.850],[.574,.868],[.476,.851],[.405,.866],[.334,.825],[.297,.758]],[[.116,.709],[.180,.674],[.259,.686],[.333,.717],[.397,.765],[.427,.849],[.418,.882],[.347,.917],[.248,.926],[.169,.901],[.118,.856],[.093,.786]]],
 [[[.332,.703],[.407,.658],[.524,.644],[.634,.661],[.736,.684],[.817,.730],[.855,.792],[.846,.840],[.793,.871],[.688,.877],[.578,.860],[.482,.885],[.408,.859],[.358,.798]],[[.143,.747],[.213,.699],[.300,.701],[.375,.746],[.415,.809],[.451,.871],[.435,.917],[.365,.952],[.282,.951],[.215,.928],[.166,.876],[.132,.814]]]]
for i,p in enumerate(ores):add(f'ore_{i}',max(q[1] for poly in p for q in poly),p,f'Iron outcrop variant {i}: separate large rock and foreground stone ground contacts, individually measured. Mineral paint is not collision geometry.')

branches=[
 [[.323,.739],[.396,.723],[.485,.755],[.549,.730],[.632,.745],[.671,.783],[.699,.819],[.724,.838],[.752,.879],[.744,.955],[.710,.972],[.676,.950],[.616,.911],[.547,.868],[.493,.832],[.430,.816],[.374,.799],[.320,.773]],
 [[.151,.636],[.206,.613],[.272,.655],[.327,.695],[.391,.741],[.456,.790],[.495,.823],[.508,.852],[.500,.902],[.478,.941],[.440,.959],[.402,.937],[.372,.910],[.342,.868],[.301,.832],[.263,.788],[.220,.748],[.176,.698]],
 [[.378,.776],[.423,.746],[.469,.756],[.521,.792],[.563,.791],[.601,.823],[.636,.852],[.714,.893],[.737,.941],[.718,.969],[.669,.958],[.606,.930],[.558,.908],[.511,.901],[.480,.938],[.442,.967],[.405,.957],[.405,.921],[.439,.875],[.435,.834]]]
for i,poly in enumerate(branches):add(f'resource_branch_{i}',max(p[1] for p in poly),[poly],f'Harvestable shrub variant {i}: woody stem/branch contact only; the actual branch differs per image and mirror. Berry nodes use this same source shrub.')

rocks=[
 [[[.162,.630],[.246,.588],[.349,.603],[.455,.641],[.562,.686],[.606,.744],[.595,.808],[.529,.862],[.432,.893],[.328,.896],[.251,.872],[.185,.822],[.143,.737]],[[.582,.762],[.630,.707],[.697,.691],[.776,.723],[.842,.766],[.874,.818],[.874,.878],[.827,.907],[.751,.918],[.677,.918],[.613,.882],[.578,.827]]],
 [[[.202,.674],[.280,.630],[.370,.627],[.455,.651],[.528,.690],[.576,.744],[.576,.790],[.532,.840],[.448,.874],[.361,.905],[.275,.886],[.224,.851],[.191,.782]],[[.466,.824],[.517,.773],[.576,.746],[.661,.755],[.739,.788],[.796,.831],[.802,.891],[.754,.946],[.689,.974],[.594,.976],[.526,.953],[.477,.909]]],
 [[[.366,.660],[.473,.606],[.579,.620],[.670,.655],[.746,.694],[.790,.757],[.785,.811],[.751,.856],[.671,.883],[.576,.908],[.489,.891],[.416,.863],[.370,.808]],[[.134,.740],[.198,.683],[.276,.669],[.365,.706],[.445,.742],[.494,.792],[.508,.851],[.466,.900],[.401,.916],[.313,.926],[.225,.920],[.176,.878],[.138,.820]]]]
for i,p in enumerate(rocks):add(f'resource_rock_{i}',max(q[1] for poly in p for q in poly),p,f'Harvest rock variant {i}, separately traced contacts for primary boulder and smaller stone; vegetation is passable.')

ropes=[
 [[.303,.759],[.369,.746],[.427,.779],[.481,.761],[.541,.781],[.591,.753],[.652,.791],[.670,.845],[.644,.883],[.574,.891],[.513,.906],[.466,.890],[.407,.903],[.353,.884],[.301,.853],[.279,.809]],
 [[.301,.776],[.364,.751],[.422,.777],[.477,.746],[.523,.776],[.575,.762],[.629,.807],[.670,.838],[.634,.881],[.581,.897],[.511,.902],[.442,.885],[.387,.903],[.330,.882],[.295,.837]],
 [[.311,.779],[.374,.771],[.420,.800],[.472,.771],[.514,.789],[.563,.770],[.625,.806],[.648,.852],[.613,.899],[.554,.920],[.501,.903],[.435,.925],[.375,.902],[.321,.875],[.289,.829]]]
for i,poly in enumerate(ropes):add(f'resource_rope_{i}',max(p[1] for p in poly),[poly],f'Soft fibre/reed clump variant {i}, interaction footprint only; deliberately passable, not a blocking solid. Tall seed heads excluded.')

spent_branches=[
 [[.357,.687],[.411,.659],[.470,.666],[.510,.703],[.558,.720],[.583,.760],[.572,.796],[.531,.833],[.477,.842],[.432,.816],[.390,.817],[.356,.779]],
 [[.396,.650],[.440,.621],[.479,.638],[.524,.685],[.553,.736],[.549,.783],[.522,.815],[.469,.835],[.424,.805],[.393,.782],[.372,.721]],
 [[.395,.619],[.446,.630],[.489,.658],[.531,.689],[.576,.694],[.597,.739],[.590,.783],[.541,.811],[.491,.818],[.446,.792],[.413,.763],[.388,.703]]]
for i,poly in enumerate(spent_branches):add(f'resource_branch_spent_{i}',max(p[1] for p in poly),[poly],f'Cut woody shrub remnant {i}, smaller persistent contact traced on its actual depleted sprite.')
spent_rocks=[
 [[[.068,.735],[.123,.689],[.188,.687],[.243,.719],[.279,.772],[.260,.821],[.204,.853],[.130,.851],[.068,.824],[.032,.781]],[[.309,.717],[.378,.678],[.455,.673],[.529,.705],[.587,.752],[.602,.802],[.564,.844],[.491,.865],[.409,.860],[.349,.831],[.302,.779]],[[.653,.755],[.715,.720],[.780,.729],[.823,.756],[.855,.792],[.850,.838],[.798,.860],[.733,.853],[.683,.829]]],
 [[[.257,.608],[.340,.565],[.441,.594],[.514,.640],[.556,.691],[.549,.749],[.483,.798],[.398,.808],[.326,.779],[.269,.731]],[[.362,.762],[.427,.715],[.493,.687],[.556,.710],[.620,.757],[.651,.808],[.641,.865],[.587,.913],[.518,.930],[.453,.904],[.405,.863],[.368,.809]]],
 [[[.184,.679],[.250,.635],[.334,.630],[.420,.664],[.480,.711],[.493,.769],[.460,.813],[.384,.844],[.300,.849],[.232,.821],[.184,.770]],[[.511,.762],[.571,.719],[.641,.713],[.704,.745],[.769,.782],[.790,.833],[.748,.881],[.682,.901],[.612,.879],[.549,.851]],[[.315,.854],[.371,.811],[.438,.800],[.493,.829],[.524,.876],[.505,.923],[.446,.954],[.390,.957],[.333,.933],[.300,.890]]]]
for i,p in enumerate(spent_rocks):add(f'resource_rock_spent_{i}',max(q[1] for poly in p for q in poly),p,f'Depleted rock remnant {i}: each surviving individual stone gets its own irregular contact; gaps remain open.')
spent_ropes=[
 [[.328,.692],[.387,.666],[.438,.704],[.477,.684],[.534,.707],[.582,.683],[.636,.723],[.656,.774],[.620,.821],[.561,.846],[.498,.834],[.436,.855],[.375,.828],[.328,.785],[.302,.738]],
 [[.339,.695],[.390,.675],[.447,.709],[.494,.686],[.540,.721],[.586,.706],[.625,.752],[.651,.800],[.611,.834],[.547,.858],[.486,.842],[.426,.861],[.376,.834],[.332,.782]],
 [[.346,.682],[.405,.660],[.451,.697],[.493,.675],[.553,.704],[.599,.688],[.639,.738],[.657,.787],[.619,.830],[.554,.849],[.491,.833],[.433,.856],[.380,.828],[.333,.774]]]
for i,poly in enumerate(spent_ropes):add(f'resource_rope_spent_{i}',max(p[1] for p in poly),[poly],f'Cut soft reed remnant {i}: interaction/attachment contact only; stays passable after gathering.')
add('gate',.924,[
 [[.125,.699],[.167,.667],[.224,.669],[.276,.687],[.305,.728],[.334,.759],[.323,.793],[.285,.816],[.231,.837],[.185,.827],[.129,.812],[.101,.775]],
 [[.625,.784],[.673,.753],[.715,.748],[.762,.769],[.797,.793],[.835,.824],[.854,.864],[.835,.899],[.794,.920],[.734,.924],[.681,.908],[.636,.883],[.604,.838]]],'Two individually traced stone post bases. Arch overhang and central opening are excluded from ground solids so passage remains open.')

def largest_component(mask):
    h,w=mask.shape;seen=np.zeros_like(mask);best=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]:continue
        q=deque([(int(x),int(y))]);seen[y,x]=True;component=[]
        while q:
            px,py=q.popleft();component.append((px,py))
            for nx,ny in [(px+1,py),(px-1,py),(px,py+1),(px,py-1)]:
                if 0<=nx<w and 0<=ny<h and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=True;q.append((nx,ny))
        if len(component)>len(best):best=component
    out=np.zeros_like(mask)
    for x,y in best:out[y,x]=True
    return out

def boundary(mask):
    h,w=mask.shape;edges={}
    for y,x in zip(*np.where(mask)):
        x=int(x);y=int(y)
        if y==0 or not mask[y-1,x]:edges.setdefault((x,y),[]).append((x+1,y))
        if x==w-1 or not mask[y,x+1]:edges.setdefault((x+1,y),[]).append((x+1,y+1))
        if y==h-1 or not mask[y+1,x]:edges.setdefault((x+1,y+1),[]).append((x,y+1))
        if x==0 or not mask[y,x-1]:edges.setdefault((x,y+1),[]).append((x,y))
    loops=[]
    while edges:
        start=next(iter(edges));p=start;loop=[p]
        for step in range(h*w*4):
            targets=edges.get(p,[])
            if not targets:break
            nxt=targets.pop()
            if not targets:edges.pop(p,None)
            p=nxt
            if p==start:break
            loop.append(p)
        if len(loop)>2:loops.append(loop)
    def area(poly):return abs(sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly))))
    return max(loops,key=area)
def rdp(points,eps):
    a=np.asarray(points[0]);b=np.asarray(points[-1]);v=b-a;length=np.linalg.norm(v)
    distances=[abs(v[0]*(p[1]-a[1])-v[1]*(p[0]-a[0]))/length if length else np.linalg.norm(np.asarray(p)-a) for p in points]
    index=int(np.argmax(distances))
    if distances[index]>eps:return rdp(points[:index+1],eps)[:-1]+rdp(points[index:],eps)
    return [points[0],points[-1]]

# These per-image limits mark the visible/inferred shoreline behind reeds.
# They exclude tall teal reed blades that otherwise pass the water-color test.
# They are distinct hand-measured contours, rather than generic ellipses.
water_envelopes=[
 [[.124,.394],[.164,.326],[.230,.283],[.278,.237],[.348,.232],[.407,.224],[.452,.206],[.514,.221],[.579,.233],[.639,.239],[.691,.283],[.739,.344],[.790,.377],[.834,.417],[.860,.479],[.869,.549],[.875,.609],[.840,.685],[.812,.746],[.756,.807],[.683,.833],[.600,.844],[.529,.835],[.451,.839],[.379,.830],[.314,.796],[.246,.762],[.209,.704],[.166,.658],[.142,.590],[.112,.524],[.111,.455]],
 [[.159,.371],[.214,.331],[.281,.309],[.306,.247],[.376,.240],[.427,.271],[.489,.282],[.557,.262],[.613,.253],[.664,.237],[.699,.283],[.745,.317],[.754,.375],[.820,.411],[.863,.465],[.891,.497],[.888,.564],[.868,.632],[.839,.703],[.803,.757],[.756,.811],[.698,.850],[.633,.866],[.564,.872],[.513,.830],[.446,.818],[.374,.793],[.319,.750],[.283,.695],[.238,.652],[.219,.606],[.186,.565],[.153,.507],[.136,.462],[.142,.411]],
 [[.135,.404],[.180,.362],[.226,.328],[.278,.323],[.332,.310],[.387,.248],[.466,.257],[.525,.257],[.602,.265],[.628,.302],[.652,.364],[.699,.388],[.741,.413],[.774,.472],[.816,.497],[.866,.535],[.894,.584],[.866,.625],[.835,.679],[.807,.728],[.751,.770],[.688,.806],[.626,.835],[.579,.863],[.547,.820],[.478,.833],[.405,.835],[.352,.806],[.315,.762],[.279,.703],[.239,.654],[.226,.593],[.194,.555],[.173,.515],[.146,.464]]]
for i in range(3):
    im=Image.open(BASE/f'pond_{i}.png').convert('RGBA');arr=np.asarray(im,dtype=float);r,g,b,a=[arr[:,:,j] for j in range(4)]
    # Blue/teal water is separated from yellow-green rim grass and gray rocks.
    raw=(a>180)&(b>r+11)&(g>r+12)&(b>g*.74)&(g>45)
    mask=np.asarray(Image.fromarray((raw*255).astype('uint8')).filter(ImageFilter.MaxFilter(11)).filter(ImageFilter.MinFilter(11)))>127
    envelope=Image.new('L',im.size);ed=ImageDraw.Draw(envelope)
    ed.polygon([(x*im.width,y*im.height) for x,y in water_envelopes[i]],fill=255)
    mask &= np.asarray(envelope)>127
    mask=largest_component(mask)
    Image.fromarray((mask*255).astype('uint8')).save(BASE/f'pond_{i}-water-mask.png')
    path=boundary(mask);w,h=im.size
    uv=[(x/w,y/h) for x,y in path]
    # Split ring at its farthest point so the closed curve simplifies reliably.
    far=max(range(len(uv)),key=lambda k:math.dist(uv[0],uv[k]));eps=.005
    while True:
        poly=rdp(uv[:far+1],eps)[:-1]+rdp(uv[far:]+[uv[0]],eps)[:-1]
        if len(poly)<=48:break
        eps*=1.15
    poly=[[round(x,4),round(y,4)] for x,y in poly]
    add(f'pond_{i}',max(p[1] for p in poly),[poly],f'Water variant {i} shoreline traced from its own blue/teal color mask and constrained by its hand-measured shore behind reeds, closed across paint speckles and simplified by {eps:.4f} UV; excludes tall teal reeds, bank flowers and dry gray rocks. Not an ellipse.')

OUT.write_text(json.dumps(profiles,indent=2)+'\n')
coverage={'source':'Exact cropped Godot 0.1.5.6 runtime sprites exported by export_profile_sprites.gd','profile_count':len(profiles),'polygon_count':sum(len(p['polygons']) for p in profiles.values()),'expected_keys':list(profiles),'coordinates':'UV within cropped runtime sprite, with existing sprite_rect and foot_anchors. Mirror tree and resource points exactly with their draw transforms.','solid_exclusions':['resource_rope_* and resource_rope_spent_* are interaction footprints, not solids','tree canopies','decorative flowers/grass','cast shadows','gate arch and opening'],'validation':'All 45 exported images inspected in labeled UV contact sheets; red boundaries and blue depth lines reviewed after generation. Runtime geometric tests are owned by main integration.'}
(BASE/'coverage.json').write_text(json.dumps(coverage,indent=2)+'\n')
print('COLLISION_PROFILES_WRITTEN',len(profiles),'polygons',coverage['polygon_count'])
