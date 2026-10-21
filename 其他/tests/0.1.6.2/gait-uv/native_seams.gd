extends RefCounted
## Offline source-edge joins. No image pixel or physical contour is changed.
## Keep this authoring helper in tests; the compiled seam records ship in the bin.
static var last_stats:Dictionary={}
const SNAP:=1000.0
static func _canonical(a:Vector2,b:Vector2)->Dictionary:
	var qa:=Vector2i(roundi(a.x*SNAP),roundi(a.y*SNAP));var qb:=Vector2i(roundi(b.x*SNAP),roundi(b.y*SNAP))
	if qa.x>qb.x or qa.x==qb.x and qa.y>qb.y:
		var q:Vector2i=qa;qa=qb;qb=q
		var p:Vector2=a;a=b;b=p
	return {"key":Vector4i(qa.x,qa.y,qb.x,qb.y),"a":a,"b":b}
static func _painted(image:Image,p:Vector2,q:Vector2,origin:Vector2)->bool:
	for t in [.1,.3,.5,.7,.9]:
		var at:Vector2=p.lerp(q,t)+origin
		var x:int=clampi(floori(at.x),0,image.get_width()-1);var y:int=clampi(floori(at.y),0,image.get_height()-1)
		if image.get_pixel(x,y).a>.1:return true
	return false
static func extract_native_seams(entry:Dictionary,definition:Dictionary,metadata:Dictionary,image:Image)->Array:
	var boundary:Dictionary={};var matched:Dictionary={};var seams:Array=[]
	var cell:=Vector2(float(metadata.cell[0]),float(metadata.cell[1]))
	var origin:=Vector2(int(definition.direction)*cell.x,0)
	var texture_size:=Vector2(image.get_width(),image.get_height())
	for raw_owner in entry.parts:
		var owner:int=int(raw_owner);var part:Dictionary=entry.parts[raw_owner]
		var local:Dictionary={};var points:PackedVector2Array=part.source_points;var indices:PackedInt32Array=part.indices
		for start in range(0,indices.size(),3):
			var tri:Array=[int(indices[start]),int(indices[start+1]),int(indices[start+2])]
			for pair in [[tri[0],tri[1]],[tri[1],tri[2]],[tri[2],tri[0]]]:
				var edge:Dictionary=_canonical(points[pair[0]],points[pair[1]])
				if edge.a.distance_squared_to(edge.b)<.000001:continue
				if not local.has(edge.key):local[edge.key]={"count":0,"owner":owner,"a":edge.a,"b":edge.b}
				local[edge.key].count+=1
		for key in local:
			if int(local[key].count)!=1:continue
			if not boundary.has(key):boundary[key]=[]
			boundary[key].append(local[key])
	var candidates:=0;var fallback_pairs:=0;var rejected_alpha:=0;var body_pairs:=0;var leg_pairs:=0
	for key in boundary:
		var records:Array=boundary[key]
		if records.size()!=2 or int(records[0].owner)==int(records[1].owner):continue
		matched[key]=true;candidates+=1
		var p:Vector2=(records[0].a+records[1].a)*.5;var q:Vector2=(records[0].b+records[1].b)*.5
		if not _painted(image,p,q,origin):rejected_alpha+=1;continue
		var owners:Array=[int(records[0].owner),int(records[1].owner)]
		seams.append({"owners":owners,"points":PackedVector2Array([p,q]),"uvs":PackedVector2Array([(origin+p)/texture_size,(origin+q)/texture_size])})
		if -1 in owners:body_pairs+=1
		else:leg_pairs+=1
	# Exact clipping can subdivide one side of a shared edge into two pieces.
	# Pair the remaining collinear interval overlaps, without creating joins to
	# unrelated silhouettes or to a same-owner internal triangulation edge.
	var lines:Dictionary={}
	for key in boundary:
		if matched.has(key):continue
		for edge in boundary[key]:
			var axis:Vector2=(edge.b-edge.a).normalized()
			var normal:=Vector2(-axis.y,axis.x);var offset:float=normal.dot(edge.a)
			var line_key:=Vector3i(roundi(axis.x*SNAP),roundi(axis.y*SNAP),roundi(offset*SNAP))
			if not lines.has(line_key):lines[line_key]=[]
			lines[line_key].append({"owner":edge.owner,"a":edge.a,"b":edge.b,"axis":axis,"normal":normal,"offset":offset})
	for line_key in lines:
		var records:Array=lines[line_key]
		for i in range(records.size()):
			var a:Dictionary=records[i]
			for j in range(i+1,records.size()):
				var b:Dictionary=records[j]
				if int(a.owner)==int(b.owner):continue
				var axis:Vector2=a.axis;var normal:Vector2=a.normal
				if absf(normal.dot(b.a)-float(a.offset))>.003 or absf(normal.dot(b.b)-float(a.offset))>.003:continue
				var lo:float=maxf(axis.dot(a.a),axis.dot(b.a));var hi:float=minf(axis.dot(a.b),axis.dot(b.b))
				if hi-lo<.001:continue
				var offset:float=(float(a.offset)+normal.dot(b.a))*.5
				var p:Vector2=axis*lo+normal*offset;var q:Vector2=axis*hi+normal*offset
				candidates+=1
				if not _painted(image,p,q,origin):rejected_alpha+=1;continue
				var owners:Array=[int(a.owner),int(b.owner)]
				seams.append({"owners":owners,"points":PackedVector2Array([p,q]),"uvs":PackedVector2Array([(origin+p)/texture_size,(origin+q)/texture_size])})
				fallback_pairs+=1
				if -1 in owners:body_pairs+=1
				else:leg_pairs+=1
	last_stats={"boundary_keys":boundary.size(),"coincident_candidates":candidates,"opaque_seams":seams.size(),"body_pairs":body_pairs,"leg_pairs":leg_pairs,"split_interval_pairs":fallback_pairs,"rejected_transparent":rejected_alpha}
	return seams
