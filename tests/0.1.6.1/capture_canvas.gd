extends Node2D
# A software capture of the game's own paint commands for reproducible visual QA.
# Regular game builds still use Godot's original canvas calls.
var commands: Array = []
var saved_textures: Dictionary = {}
var saved_meshes: Dictionary = {}
var output_dir := "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.1/captures"
var paint_offset := Vector2.ZERO
var paint_angle := 0.0
var paint_scale := Vector2.ONE
func reset_capture():
 commands.clear()
 paint_offset=Vector2.ZERO;paint_angle=0;paint_scale=Vector2.ONE
func color_data(c:Color)->Array: return [c.r,c.g,c.b,c.a]
func rect_data(r:Rect2)->Array: return [r.position.x,r.position.y,r.size.x,r.size.y]
func transform_data()->Array: return [paint_offset.x,paint_offset.y,paint_angle,paint_scale.x,paint_scale.y]
func append_paint(command:Dictionary):
 command["transform"]=transform_data()
 commands.append(command)
func texture_data(texture:Texture2D)->Dictionary:
 var key := str(texture.get_instance_id())
 if not saved_textures.has(key):
  var pixels := texture.get_image()
  var path := output_dir+"/texture-"+str(OS.get_process_id())+"-"+key+".png"
  pixels.save_png(path)
  saved_textures[key]={"path":path,"width":pixels.get_width(),"height":pixels.get_height()}
 return saved_textures[key]
func record_draw_set_transform(offset:Vector2,rotation:float=0,scale:Vector2=Vector2.ONE):
 paint_offset=offset;paint_angle=rotation;paint_scale=scale
func record_draw_texture_rect(texture:Texture2D,rect:Rect2,_tile:bool,modulate:Color=Color.WHITE,_transpose:bool=false):
 append_paint({"kind":"texture","texture":texture_data(texture),"rect":rect_data(rect),"color":color_data(modulate)})
func record_draw_texture_rect_region(texture:Texture2D,rect:Rect2,source:Rect2,modulate:Color=Color.WHITE,_transpose:bool=false,_clip_uv:bool=true):
 append_paint({"kind":"texture","texture":texture_data(texture),"rect":rect_data(rect),"source":rect_data(source),"color":color_data(modulate)})
func record_draw_rect(rect:Rect2,color:Color,filled:bool=true,width:float=-1,_antialias:bool=false):
 append_paint({"kind":"rect","rect":rect_data(rect),"color":color_data(color),"filled":filled,"width":maxf(1,width)})
func record_draw_circle(p:Vector2,radius:float,color:Color,filled:bool=true,width:float=-1,_antialias:bool=false):
 append_paint({"kind":"circle","p":[p.x,p.y],"radius":radius,"color":color_data(color),"filled":filled,"width":maxf(1,width)})
func record_draw_line(a:Vector2,b:Vector2,color:Color,width:float=-1,_antialias:bool=false):
 append_paint({"kind":"line","a":[a.x,a.y],"b":[b.x,b.y],"color":color_data(color),"width":maxf(1,width)})
func record_draw_colored_polygon(points:PackedVector2Array,color:Color,uvs:PackedVector2Array=PackedVector2Array(),texture:Texture2D=null):
 var vertices:Array=[]
 for p in points:vertices.append([p.x,p.y])
 if texture != null and uvs.size() == points.size():
  var raw_uvs:Array=[]
  for uv in uvs:raw_uvs.append([uv.x,uv.y])
  var triangles:Array=[]
  for index in Geometry2D.triangulate_polygon(points):triangles.append(index)
  append_paint({"kind":"textured_polygon","points":vertices,"uvs":raw_uvs,"triangles":triangles,"texture":texture_data(texture),"color":color_data(color)})
 else:append_paint({"kind":"polygon","points":vertices,"color":color_data(color)})
func record_draw_polyline(points:PackedVector2Array,color:Color,width:float=-1,_antialias:bool=false):
 var vertices:Array=[]
 for p in points:vertices.append([p.x,p.y])
 append_paint({"kind":"polyline","points":vertices,"color":color_data(color),"width":maxf(1,width)})
func record_draw_style_box(style:StyleBox,rect:Rect2):
 append_paint({"kind":"panel","rect":rect_data(rect),"color":color_data(style.bg_color),"radius":style.corner_radius_top_left,"border":color_data(style.border_color)})
func record_draw_string(_font:Font,p:Vector2,text:String,_alignment:int=0,_width:float=-1,font_size:int=16,color:Color=Color.WHITE):
 append_paint({"kind":"text","p":[p.x,p.y],"text":text,"size":font_size,"color":color_data(color)})
func mesh_data(mesh:Mesh)->Dictionary:
 var key := str(mesh.get_instance_id())
 if not saved_meshes.has(key):
  var surfaces:Array=[]
  var bounds := Rect2()
  var first := true
  for surface_index in range(mesh.get_surface_count()):
   var arrays := mesh.surface_get_arrays(surface_index)
   var vertices:Array=[]
   var colors:Array=[]
   var indices:Array=[]
   for p in arrays[Mesh.ARRAY_VERTEX]:
    vertices.append([p.x,p.y])
    if first:
     bounds=Rect2(Vector2(p.x,p.y),Vector2.ZERO);first=false
    else:bounds=bounds.expand(Vector2(p.x,p.y))
   if arrays[Mesh.ARRAY_COLOR] != null:
    for color in arrays[Mesh.ARRAY_COLOR]:colors.append(color_data(color))
   if arrays[Mesh.ARRAY_INDEX] != null:
    for index in arrays[Mesh.ARRAY_INDEX]:indices.append(index)
   surfaces.append({"vertices":vertices,"colors":colors,"indices":indices,"primitive":mesh.surface_get_primitive_type(surface_index)})
  var path := output_dir+"/mesh-"+str(OS.get_process_id())+"-"+key+".json"
  var file := FileAccess.open(path,FileAccess.WRITE)
  file.store_string(JSON.stringify({"surfaces":surfaces,"bounds":rect_data(bounds)}))
  file.close()
  saved_meshes[key]={"path":path,"bounds":rect_data(bounds)}
 return saved_meshes[key]
func record_draw_mesh(mesh:Mesh,texture:Texture2D=null,transform:Transform2D=Transform2D.IDENTITY,modulate:Color=Color.WHITE):
 var command := {"kind":"mesh","mesh":mesh_data(mesh),"color":color_data(modulate),"mesh_transform":[transform.x.x,transform.x.y,transform.y.x,transform.y.y,transform.origin.x,transform.origin.y]}
 if texture != null:command["texture"]=texture_data(texture)
 append_paint(command)
func record_ground_layer(layer,camera:Vector2=Vector2.ZERO):
 if layer == null:return
 record_draw_set_transform(-camera,layer.rotation,layer.scale)
 if layer.ground_texture != null:
  record_draw_texture_rect(layer.ground_texture,Rect2(Vector2.ZERO,layer.world_size),false)
 else:record_draw_rect(Rect2(Vector2.ZERO,layer.world_size),Color("71927b"))
 if layer.detail_mesh != null:record_draw_mesh(layer.detail_mesh)
func save_capture(name:String,width:int=1100,height:int=720):
 var file:=FileAccess.open(output_dir+"/"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"width":width,"height":height,"commands":commands}))
