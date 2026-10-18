extends RefCounted
## Native painted UV skinning. Every pixel comes from the unmodified .6 atlas.
## Native body and original paw dimensions reconstruct exactly at rest.
const STEP:=4
static func v(a:Array)->Vector2:return Vector2(float(a[0]),float(a[1]))
static func foot_cycle(t:float,reach:float,lift:float)->Vector2:
	t=fposmod(t,1.0)
	if t<.5:return Vector2(reach-4*reach*t,0)
	var q:float=(t-.5)*2
	return Vector2(-reach*cos(PI*q),lift*sin(PI*q))
static func rot_point(point:Vector2,pivot:Vector2,angle:float)->Vector2:return pivot+(point-pivot).rotated(angle)
static func triangle_sign(a:Vector2,b:Vector2,c:Vector2)->float:return (b-a).cross(c-a)
static func posed_leg(leg:Dictionary,phase:float,moving:bool)->Dictionary:
	var root:Vector2=v(leg.root);var knee:Vector2=v(leg.knee);var ankle:Vector2=v(leg.ankle)
	var target_ankle:Vector2=ankle+v(leg.get("rest_shift",[0,0])) if moving else ankle
	if moving:
		var c:Vector2=foot_cycle(phase+float(leg.phase),float(leg.get("reach",15)),float(leg.get("lift",7)))
		target_ankle+=v(leg.get("forward",[1,.0]))*c.x+Vector2(0,-c.y)
	var upper:float=root.distance_to(knee);var lower:float=knee.distance_to(ankle)
	var axis:Vector2=target_ankle-root
	var distance:float=clampf(axis.length(),absf(upper-lower)+.001,upper+lower-.001)
	axis=axis.normalized()
	var along:float=(upper*upper-lower*lower+distance*distance)/(2*distance)
	var height:float=sqrt(maxf(0,upper*upper-along*along))
	var sign:float=signf((ankle-root).cross(knee-root))
	var target_knee:Vector2=root+axis*along+Vector2(-axis.y,axis.x)*height*sign
	target_ankle=root+axis*distance
	if not moving:target_knee=knee;target_ankle=ankle
	return {"root":root,"knee":knee,"ankle":ankle,"target_knee":target_knee,"target_ankle":target_ankle,"upper_angle":(target_knee-root).angle()-(knee-root).angle(),"lower_angle":(target_ankle-target_knee).angle()-(ankle-knee).angle()}
static func deform_leg(point:Vector2,leg:Dictionary,p:Dictionary,moving:bool)->Vector2:
	if not moving:return point
	var axis:Vector2=p.ankle-p.root
	var t:float=(point-p.root).dot(axis)/axis.length_squared()
	var upper:Vector2=rot_point(point,p.root,p.upper_angle)
	var lower:Vector2=p.target_knee+(point-p.knee).rotated(float(p.lower_angle))
	var paw:Vector2=point+p.target_ankle-p.ankle
	var result:Vector2=upper.lerp(lower,smoothstep(.32,.68,t)).lerp(paw,smoothstep(.60,1.15,t))
	# Full attachment seam stays fixed. Leg-mask boundaries in empty alpha may
	# disconnect safely; there are no fixed vertices pulling a moving leg mesh.
	return point.lerp(result,smoothstep(.16,.64,t))
static func deform(point:Vector2,legs:Array,poses:Array,moving:bool)->Vector2:
	for index in range(legs.size()):
		var mask:=PackedVector2Array()
		for raw in legs[index].mask:mask.append(v(raw))
		if Geometry2D.is_point_in_polygon(point,mask):return deform_leg(point,legs[index],poses[index],moving)
	return point
static var _topology:Dictionary={}
static func topology(definition:Dictionary,cell:Vector2)->Dictionary:
	var key:String=JSON.stringify(definition)+str(cell)
	if _topology.has(key):return _topology[key]
	var masks:Array=[]
	for leg in definition.legs:
		var mask:=PackedVector2Array()
		for raw in leg.mask:mask.append(v(raw))
		masks.append(mask)
	var source:=PackedVector2Array();var ownership:=PackedInt32Array();var indices:=PackedInt32Array();var lookup:Dictionary={}
	var pieces:Array=[]
	var bounds:Array=[]
	for mask in masks:
		var rect:=Rect2(mask[0],Vector2.ZERO)
		for point in mask:rect=rect.expand(point)
		bounds.append(rect.grow(.01))
	var source_triangles:Array=[]
	# A coarse affine UV body is pixel-identical to a dense mesh. Fine 4px
	# tessellation is confined to leg masks; bitmap sampling stays native.
	for block_row in range(int(cell.y/32)):
		for block_col in range(int(cell.x/32)):
			var rect:=Rect2(block_col*32,block_row*32,32,32)
			var near_leg:=false
			for bound in bounds:
				if rect.intersects(bound):near_leg=true;break
			var step:int=STEP if near_leg else 32
			for yy in range(0,32,step):
				for xx in range(0,32,step):
					var a:=rect.position+Vector2(xx,yy);var b:=a+Vector2(step,0);var c:=a+Vector2(0,step);var d:=a+Vector2(step,step)
					source_triangles.append(PackedVector2Array([a,b,c]));source_triangles.append(PackedVector2Array([b,d,c]))
	for triangle in source_triangles:
		var remainder:Array=[triangle]
		for leg_index in range(masks.size()):
			var next:Array=[]
			for polygon in remainder:
				for clipped in Geometry2D.intersect_polygons(polygon,masks[leg_index]):pieces.append({"points":clipped,"owner":leg_index})
				next.append_array(Geometry2D.clip_polygons(polygon,masks[leg_index]))
			remainder=next
			if remainder.is_empty():break
		for polygon in remainder:pieces.append({"points":polygon,"owner":-1})

	# Draw the fixed body after the articulated pieces to cover root attachment.
	pieces.sort_custom(func(a,b):return int(a.owner)>int(b.owner))
	for piece in pieces:
		var tris:PackedInt32Array=Geometry2D.triangulate_polygon(piece.points)
		if tris.is_empty():continue
		var local_indices:Array=[]
		for point in piece.points:
			var vertex_key:String=str(piece.owner)+":"+str(snappedf(point.x,.00001))+":"+str(snappedf(point.y,.00001))
			if not lookup.has(vertex_key):
				lookup[vertex_key]=source.size();source.append(point);ownership.append(int(piece.owner))
			local_indices.append(int(lookup[vertex_key]))
		for start in range(0,tris.size(),3):
			var ia:int=int(tris[start]);var ib:int=int(tris[start+1]);var ic:int=int(tris[start+2])
			if absf(triangle_sign(piece.points[ia],piece.points[ib],piece.points[ic]))<.00001:continue
			indices.append(local_indices[ia]);indices.append(local_indices[ib]);indices.append(local_indices[ic])
	var result:Dictionary={"source_points":source,"ownership":ownership,"indices":indices}
	_topology[key]=result
	return result
static func geometry(definition:Dictionary,phase:float,moving:bool,cell:Vector2=Vector2(384,384),texture_size:Vector2=Vector2(3072,1536))->Dictionary:
	var legs:Array=definition.legs
	var poses:Array=[]
	for leg in legs:poses.append(posed_leg(leg,phase,moving))
	var native_points:=PackedVector2Array();var uvs:=PackedVector2Array()
	var source_origin:=Vector2(int(definition.direction)*cell.x,0)
	var t:Dictionary=topology(definition,cell)
	for index in range(t.source_points.size()):
		var point:Vector2=t.source_points[index];var owner:int=int(t.ownership[index])
		native_points.append(deform_leg(point,legs[owner],poses[owner],moving) if owner>=0 else point)
		uvs.append((source_origin+point)/texture_size)
	return {"source_points":t.source_points,"native_points":native_points,"points":native_points,"uvs":uvs,"indices":t.indices,"ownership":t.ownership,"legs":poses,"source_rect":Rect2(source_origin,cell)}
static func mesh(drawing:Dictionary,scale:float=1.0,anchor:Vector2=Vector2.ZERO)->ArrayMesh:
	var vertices:=PackedVector3Array()
	for point in drawing.native_points:vertices.append(Vector3((point.x-anchor.x)*scale,(point.y-anchor.y)*scale,0))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=drawing.uvs;arrays[Mesh.ARRAY_INDEX]=drawing.indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

## Offline compilation partitions source UV coverage exactly once. Runtime only
## poses actual leg vertices; the body mesh and source topology are static.
static func compile_entry(definition:Dictionary,cell:Vector2,texture_size:Vector2)->Dictionary:
	var t:Dictionary=topology(definition,cell)
	var parts:Dictionary={}
	var maps:Dictionary={}
	var origin:=Vector2(int(definition.direction)*cell.x,0)
	for start in range(0,t.indices.size(),3):
		var global_index:int=int(t.indices[start]);var owner:int=int(t.ownership[global_index])
		if not parts.has(owner):
			parts[owner]={"source_points":PackedVector2Array(),"uvs":PackedVector2Array(),"indices":PackedInt32Array()};maps[owner]={}
		var part:Dictionary=parts[owner];var lookup:Dictionary=maps[owner]
		for corner in range(3):
			var index:int=int(t.indices[start+corner])
			if not lookup.has(index):
				lookup[index]=part.source_points.size();var point:Vector2=t.source_points[index]
				part.source_points.append(point);part.uvs.append((origin+point)/texture_size)
			part.indices.append(int(lookup[index]))
	return {"hash":JSON.stringify(definition).sha256_text(),"parts":parts}

static var _compiled:Dictionary={}
static var _loaded:=false
static var _body_meshes:Dictionary={}
static var _moving_meshes:Dictionary={}
static func _entry(species:String,direction:int,definition:Dictionary,metadata:Dictionary)->Dictionary:
	if not _loaded:
		_loaded=true
		if FileAccess.file_exists("res://assets/animal-skin-topology.bin"):
			var file:=FileAccess.open("res://assets/animal-skin-topology.bin",FileAccess.READ)
			var packed:Variant=file.get_var();file.close()
			if packed is Dictionary:_compiled=packed
	var key:String=species+":"+str(direction)
	var signature:String=JSON.stringify(definition).sha256_text()
	if not _compiled.has(key) or str(_compiled[key].hash)!=signature:
		var cell:=Vector2(float(metadata.cell[0]),float(metadata.cell[1]))
		_compiled[key]=compile_entry(definition,cell,Vector2(cell.x*8.0,cell.y*float(metadata.frames)))
	return _compiled[key]

static func _make_mesh(part:Dictionary,points:PackedVector2Array,scale:float,anchor:Vector2,reuse:ArrayMesh=null)->ArrayMesh:
	var vertices:=PackedVector3Array()
	for point in points:vertices.append(Vector3((point.x-anchor.x)*scale,(point.y-anchor.y)*scale,0))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=part.uvs;arrays[Mesh.ARRAY_INDEX]=part.indices
	var result:ArrayMesh=reuse if reuse!=null else ArrayMesh.new()
	result.clear_surfaces();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result

static func _submit(canvas:Object,mesh_data:ArrayMesh,texture:Texture2D,origin:Vector2,tint:Color)->void:
	if canvas.has_method("record_draw_mesh"):canvas.record_draw_mesh(mesh_data,texture,Transform2D(0,origin),tint)
	else:canvas.draw_mesh(mesh_data,texture,Transform2D(0,origin),tint)

static func draw(canvas:Object,animal:Dictionary,texture:Texture2D,pose:Dictionary,metadata:Dictionary,tint:Color=Color.WHITE)->void:
	var direction:int=int(pose.direction)
	var definitions:Dictionary=metadata.get("source_skin",{})
	var definition:Dictionary=definitions.get(str(direction),{})
	var source:Rect2=pose.source;source.position.y=0
	if definition.is_empty() or not bool(animal.get("moving",false)):
		# Idle is the complete original native painting, including all paws and fur.
		var rect:=Rect2(animal.p-pose.anchor*float(pose.scale),source.size*float(pose.scale))
		if canvas.has_method("record_draw_texture_rect_region"):canvas.record_draw_texture_rect_region(texture,rect,source,tint)
		else:canvas.draw_texture_rect_region(texture,rect,source,tint)
		return
	var entry:Dictionary=_entry(str(animal.species),direction,definition,metadata)
	var phase:float=float(animal.get("gait_phase",float(animal.get("frame",0))/8.0))
	var scale:float=float(pose.scale);var anchor:Vector2=pose.anchor
	var body_key:String=str(animal.species)+":"+str(direction)+":"+str(scale)
	var capture:bool=canvas.has_method("record_draw_mesh")
	for owner in entry.parts:
		if int(owner)<0:continue
		var part:Dictionary=entry.parts[owner]
		var leg:Dictionary=definition.legs[int(owner)]
		var leg_pose:Dictionary=posed_leg(leg,phase,true)
		var points:=PackedVector2Array()
		for point in part.source_points:points.append(deform_leg(point,leg,leg_pose,true))
		var mesh_key:String=str(animal.get("uid",animal.species))+":"+str(owner)
		var reuse:ArrayMesh=null if capture else _moving_meshes.get(mesh_key,null)
		var drawing:ArrayMesh=_make_mesh(part,points,scale,anchor,reuse)
		if not capture:_moving_meshes[mesh_key]=drawing
		_submit(canvas,drawing,texture,animal.p,tint)
	if entry.parts.has(-1):
		if not _body_meshes.has(body_key):
			var body:Dictionary=entry.parts[-1]
			_body_meshes[body_key]=_make_mesh(body,body.source_points,scale,anchor)
		_submit(canvas,_body_meshes[body_key],texture,animal.p,tint)
	if _moving_meshes.size()>256:_moving_meshes.erase(_moving_meshes.keys()[0])

static func eye_offsets(_animal:Dictionary,metadata:Dictionary,pose:Dictionary)->Array:
	var result:Array=[]
	var native:Dictionary=metadata.poses[int(pose.direction)][0]
	for raw in native.get("eyes",[]):result.append((v(raw)-pose.anchor)*float(pose.scale))
	return result
