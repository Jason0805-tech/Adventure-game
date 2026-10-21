extends SceneTree
var images := {}
func _initialize():call_deferred("run")
func alpha(species:String,direction:int,p:Vector2)->float:
 var image:Image=images[species]
 return image.get_pixel(clampi(int(p.x)+direction*384,0,image.get_width()-1),clampi(int(p.y),0,image.get_height()-1)).a
func run():
 var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json")).species
 var gait=load("res://animal_gait.gd")
 var summary:Dictionary={};var details:Array=[]
 for species in metadata:
  images[species]=Image.load_from_file("res://assets/wildlife-"+species+".png")
  var m:Dictionary=metadata[species]
  for direction in range(8):
   var definition:Dictionary=m.source_skin[str(direction)]
   for phase in [0.0,.125,.25,.375,.5,.625,.75,.875]:
    var d:Dictionary=gait.geometry(definition,phase,true)
    for i in range(0,d.indices.size(),3):
     var ids=[d.indices[i],d.indices[i+1],d.indices[i+2]]
     var a:Vector2=d.source_points[ids[0]];var b:Vector2=d.source_points[ids[1]];var c:Vector2=d.source_points[ids[2]]
     var na:Vector2=d.native_points[ids[0]];var nb:Vector2=d.native_points[ids[1]];var nc:Vector2=d.native_points[ids[2]]
     var sa:float=(b-a).cross(c-a);var da:float=(nb-na).cross(nc-na)
     if sa*da>0:continue
     var center=(a+b+c)/3.0
     var samples=[alpha(species,direction,a),alpha(species,direction,b),alpha(species,direction,c),alpha(species,direction,center),alpha(species,direction,(a+b)*.5),alpha(species,direction,(a+c)*.5),alpha(species,direction,(b+c)*.5)]
     if samples.max()<=.1:continue
     var key=species+":"+str(direction)
     if not summary.has(key):summary[key]={"folds":0,"max_source_area":0,"max_native_area":0,"area_sum":0,"folds_area_over_0_01":0,"folds_area_over_1":0,"folds_area_over_4":0}
     var s:Dictionary=summary[key];var area=absf(sa)*.5
     s.folds+=1;s.max_source_area=maxf(s.max_source_area,area);s.max_native_area=maxf(s.max_native_area,absf(da)*.5);s.area_sum+=area
     if area>.01:s.folds_area_over_0_01+=1
     if area>1:s.folds_area_over_1+=1
     if area>4:s.folds_area_over_4+=1
     if area>.01 and details.size()<200:details.append({"species":species,"direction":direction,"phase":phase,"source_area":area,"native_area":da*.5,"owner":d.ownership[ids[0]],"source":[[a.x,a.y],[b.x,b.y],[c.x,c.y]],"posed":[[na.x,na.y],[nb.x,nb.y],[nc.x,nc.y]],"alpha":samples})
 var file=FileAccess.open("res://../../tests/0.1.6.2/uv-fold-diagnosis.json",FileAccess.WRITE);file.store_string(JSON.stringify({"summary":summary,"details":details},"\t"))
 print("UV_FOLD_DIAG ",JSON.stringify(summary));quit()
