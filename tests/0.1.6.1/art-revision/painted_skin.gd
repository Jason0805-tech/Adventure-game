extends RefCounted
## Test-only UV skinning prototype. Every pixel comes from the unmodified .6 atlas.
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
	var paw_top:float=ankle.y
	for raw in leg.get("paw_mask",[]):paw_top=minf(paw_top,float(raw[1]))
	var start_y:float=root.y+maxf(0.0,(ankle.y-root.y)*.04)
	var end_y:float=maxf(start_y+8.0,paw_top)
	var delta:=Vector2.ZERO
	if moving:
		var cycle:Vector2=foot_cycle(phase+float(leg.phase),float(leg.get("reach",12)),float(leg.get("lift",6)))
		delta=v(leg.get("rest_shift",[0,0]))+v(leg.get("forward",[1,0]))*cycle.x+Vector2(0,-cycle.y)
		# For p'=p+w(y)*delta, det(J)=1+delta.y*w'(y).
		# Smoothstep has max derivative1.5/span. This bound keeps det>=0.25;
		# horizontal steps are shears and can never invert original painted legs.
		delta.y=maxf(delta.y,-.5*(end_y-start_y))
	return {"root":root,"knee":knee,"ankle":ankle,"target_ankle":ankle+delta,"target_knee":knee+delta*smoothstep(start_y,end_y,knee.y),"delta":delta,"skin_start_y":start_y,"skin_end_y":end_y}
static func deform_leg(point:Vector2,_leg:Dictionary,p:Dictionary,moving:bool)->Vector2:
	if not moving:return point
	# A wide, monotonic bend in the original painted limb. The native paw is
	# translated rigidly; no independent colors, outlines, shoes or scales exist.
	var weight:float=smoothstep(float(p.skin_start_y),float(p.skin_end_y),point.y)
	return point+p.delta*weight
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
