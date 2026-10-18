extends Node2D
# A software capture of the game's own paint commands for reproducible visual QA.
# Regular game builds still use Godot's original canvas calls.
var commands: Array = []
var saved_textures: Dictionary = {}
var output_dir := "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.5.4/captures"
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
  var path := output_dir+"/texture-"+key+".png"
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
func record_draw_colored_polygon(points:PackedVector2Array,color:Color,_uvs:PackedVector2Array=PackedVector2Array(),_texture:Texture2D=null):
 var vertices:Array=[]
 for p in points:vertices.append([p.x,p.y])
 append_paint({"kind":"polygon","points":vertices,"color":color_data(color)})
func record_draw_polyline(points:PackedVector2Array,color:Color,width:float=-1,_antialias:bool=false):
 var vertices:Array=[]
 for p in points:vertices.append([p.x,p.y])
 append_paint({"kind":"polyline","points":vertices,"color":color_data(color),"width":maxf(1,width)})
func record_draw_style_box(style:StyleBox,rect:Rect2):
 append_paint({"kind":"panel","rect":rect_data(rect),"color":color_data(style.bg_color),"radius":style.corner_radius_top_left,"border":color_data(style.border_color)})
func record_draw_string(_font:Font,p:Vector2,text:String,_alignment:int=0,_width:float=-1,font_size:int=16,color:Color=Color.WHITE):
 append_paint({"kind":"text","p":[p.x,p.y],"text":text,"size":font_size,"color":color_data(color)})
func save_capture(name:String,width:int=1100,height:int=720):
 var file:=FileAccess.open(output_dir+"/"+name+".json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"width":width,"height":height,"commands":commands}))
