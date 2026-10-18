extends RefCounted
## Native painted bodies + a continuous articulated 2D quadruped gait.
## This extends the traveler's stance/swing method, not independently redrawn keys.
## No image is mirrored, resized on disk, recolored or destructively edited.

static func foot_cycle(phase:float,reach:float,lift:float)->Vector2:
	var t:float=fposmod(phase,1.0)
	if t<0.5:
		# A planted paw moves rearwards across the projected ground plane.
		return Vector2(reach-4.0*reach*t,0.0)
	var q:float=(t-0.5)*2.0
	# Recovery goes forwards above the ground; it is never the stance in reverse.
	return Vector2(-reach*cos(PI*q),lift*sin(PI*q))

static func body_bob(species:String,phase:float,moving:bool)->float:
	if not moving:return 0.0
	if species=="rabbit":
		# Soft short bounds: crouch, push, flight, landing, then a new forward cycle.
		var t:float=fposmod(phase,1.0)
		return -8.0*pow(maxf(0.0,sin(PI*clampf((t-0.16)/0.68,0.0,1.0))),1.5)
	return -1.3*cos(TAU*2.0*phase)

static func phase_offsets(species:String,fast:bool)->Dictionary:
	if species=="rabbit":return {"front_left":0.05,"front_right":0.05,"hind_left":0.55,"hind_right":0.55}
	if species=="bear":return {"hind_left":0.0,"front_left":0.25,"hind_right":0.5,"front_right":0.75}
	# Keep the SAME anatomical phase relation when wandering becomes fleeing
	# or chasing. Speed changes cycle rate; it must not teleport two paws.
	# `fast` is intentionally accepted for API compatibility, without a pose swap.
	return {"front_left":0.0,"hind_right":0.25,"front_right":0.5,"hind_left":0.75}

static func _v(raw:Array)->Vector2:return Vector2(float(raw[0]),float(raw[1]))

static func joints(animal:Dictionary,metadata:Dictionary,direction:int,scale:float)->Array:
	var cfg:Dictionary=metadata.gait
	var rig:Dictionary=cfg.directions[direction]
	var species:String=str(animal.species)
	var moving:bool=bool(animal.get("moving",false))
	var phase:float=float(animal.get("gait_phase",float(animal.get("frame",0))/8.0))
	var fast:bool=str(animal.get("state",animal.get("activity",""))) in ["chase","flee"]
	var offsets:Dictionary=phase_offsets(species,fast)
	var angle:float=deg_to_rad(float(metadata.angles[direction]))
	var forward:=Vector2(sin(angle),cos(angle)*float(cfg.projection_y))
	var reach:float=float(cfg.stride_world)/(4.0*maxf(scale,0.001))
	var bob:float=body_bob(species,phase,moving)
	var result:Array=[]
	for original in rig.legs:
		var leg:Dictionary=original.duplicate(true)
		var root:Vector2=_v(leg.root)+Vector2(0,bob)
		var base:Vector2=_v(leg.foot)
		var cycle:Vector2=foot_cycle(phase+float(offsets[leg.name]),reach*float(leg.get("reach_factor",1.0)),float(cfg.lift)) if moving else Vector2.ZERO
		var foot:Vector2=base+forward*cycle.x+Vector2(0,-cycle.y)
		var rest_length:float=maxf(14.0,base.distance_to(_v(leg.root)))
		# Two joint segments flex about a knee/hock. The endpoints stay attached
		# to the same shoulder and paw; no whole-leg rotation about a torso pivot.
		var midpoint:Vector2=root.lerp(foot,0.52)
		var bend_sign:float=-1.0 if bool(leg.fore) else 1.0
		var bend:float=rest_length*0.13+cycle.y*0.32
		var knee:Vector2=midpoint+Vector2(sin(angle)*bend_sign*bend,-cycle.y*0.10)
		leg["root_point"]=root;leg["knee_point"]=knee;leg["foot_point"]=foot
		leg["cycle"]=cycle;leg["phase"]=fposmod(phase+float(offsets[leg.name]),1.0)
		leg["rest_length"]=rest_length
		result.append(leg)
	result.sort_custom(func(a,b):return float(a.depth)<float(b.depth))
	return result

static func _outline(a:Vector2,b:Vector2,r1:float,r2:float,seed:int)->PackedVector2Array:
	var points:=PackedVector2Array()
	if a.distance_squared_to(b)<0.0025:
		for j in range(12):points.append(a+Vector2.from_angle(TAU*float(j)/12.0)*maxf(r1,r2))
		return points
	var angle:float=(b-a).angle()
	# Rounded brush dabs at both articulated joints, rather than rigid rectangular
	# cutouts. Small fixed edge irregularities move with the same brush stroke.
	for j in range(8):
		var theta:float=angle-PI*.5+PI*float(j)/7.0
		var radius:float=r2*(.985+.015*sin(float(seed+j*11)*1.714))
		points.append(b+Vector2.from_angle(theta)*radius)
	for j in range(8):
		var theta:float=angle+PI*.5+PI*float(j)/7.0
		var radius:float=r1*(.985+.015*sin(float(seed+j*13)*1.714))
		points.append(a+Vector2.from_angle(theta)*radius)
	return points

static func _pigment(a:Vector2,b:Vector2,width:float,color:Color,seed:int)->Array:
	var polygons:Array=[]
	var axis:Vector2=(b-a).normalized();var normal:=Vector2(-axis.y,axis.x)
	for j in range(3):
		var t:float=0.16+float(j)*0.25
		var offset:float=sin(float(seed+j*17)*2.118)*width*0.42
		var start:Vector2=a.lerp(b,t)+normal*offset
		var finish:Vector2=a.lerp(b,minf(.98,t+.22))+normal*(offset+width*.12)
		var delta:float=sin(float(seed+j*7)*1.51)*0.075
		var paint:=Color(clampf(color.r+delta,0,1),clampf(color.g+delta*.83,0,1),clampf(color.b+delta*.67,0,1),color.a*.65)
		polygons.append({"points":_outline(start,finish,width*.25,width*.14,seed+j),"color":paint})
	return polygons

static func geometry(animal:Dictionary,metadata:Dictionary,pose:Dictionary,tint:Color=Color.WHITE)->Dictionary:
	var direction:int=int(pose.direction)
	var scale:float=float(pose.scale)
	var cfg:Dictionary=metadata.gait
	var rig:Dictionary=cfg.directions[direction]
	var moving:bool=bool(animal.get("moving",false))
	var phase:float=float(animal.get("gait_phase",float(animal.get("frame",0))/8.0))
	var bob:float=body_bob(str(animal.species),phase,moving)
	var origin:Vector2=animal.p-pose.anchor*scale
	var polygons:Array=[]
	var legs:Array=joints(animal,metadata,direction,scale)
	var leg_index:int=0
	for leg in legs:
		var root:Vector2=leg.root_point;var knee:Vector2=leg.knee_point;var foot:Vector2=leg.foot_point
		var width:float=float(leg.width)
		var far:bool=float(leg.depth)<302.0
		var upper:=Color(str(cfg.colors[0]))*tint;var lower:=Color(str(cfg.colors[1]))*tint;var paw:=Color(str(cfg.colors[2]))*tint
		if far:
			upper=Color(upper.r*.87,upper.g*.87,upper.b*.87,upper.a)
			lower=Color(lower.r*.87,lower.g*.87,lower.b*.87,lower.a)
			paw=Color(paw.r*.87,paw.g*.87,paw.b*.87,paw.a)
		var seed:int=direction*71+leg_index*97+str(animal.species).hash()%1009
		polygons.append({"points":_outline(root,knee,width,width*.72,seed),"color":upper})
		polygons.append_array(_pigment(root,knee,width,upper,seed))
		polygons.append({"points":_outline(knee,foot,width*.73,width*.59,seed+23),"color":lower})
		polygons.append_array(_pigment(knee,foot,width*.68,lower,seed+39))
		var paw_axis:=Vector2(sin(deg_to_rad(float(metadata.angles[direction]))),0.20)
		var paw_end:Vector2=foot+paw_axis*float(cfg.paw)*.58
		polygons.append({"points":_outline(foot-paw_axis*float(cfg.paw)*.20,paw_end,width*.64,width*.55,seed+51),"color":paw})
		polygons.append_array(_pigment(foot,paw_end,width*.6,paw,seed+81))
		leg_index+=1
	for polygon in polygons:
		var transformed:=PackedVector2Array()
		var local_points:=PackedVector2Array()
		for point in polygon.points:
			local_points.append((point-pose.anchor)*scale)
			transformed.append(origin+point*scale)
		polygon.points=transformed
		polygon.local_points=local_points
	var body_points:=PackedVector2Array()
	var body_uvs:=PackedVector2Array()
	var source:Rect2=pose.source
	# Body always samples a single native painted identity, not the old keys.
	source.position.y=float(rig.get("body_frame",0))*source.size.y
	var texture_size:=Vector2(float(metadata.cell[0])*float(metadata.angles.size()),float(metadata.cell[1])*float(metadata.frames))
	for raw in rig.body_polygon:
		var point:Vector2=_v(raw)
		body_points.append(origin+(point+Vector2(0,bob))*scale)
		body_uvs.append((source.position+point)/texture_size)
	return {"limbs":polygons,"body_points":body_points,"body_uvs":body_uvs,"tint":tint,"joints":legs,"body_bob":bob}

static func _polygon(canvas:Object,points:PackedVector2Array,color:Color,uvs:PackedVector2Array=PackedVector2Array(),texture:Texture2D=null)->void:
	if canvas.has_method("record_draw_colored_polygon"):
		canvas.record_draw_colored_polygon(points,color,uvs,texture)
	else:canvas.draw_colored_polygon(points,color,uvs,texture)

static var _limb_meshes:Dictionary={}

static func _draw_limbs(canvas:Object,animal:Dictionary,polygons:Array)->void:
	var origin:Vector2=animal.p
	var vertices:=PackedVector3Array()
	var colors:=PackedColorArray()
	var indices:=PackedInt32Array()
	for polygon in polygons:
		# Triangulate near the origin and submit explicit triangles. Native Canvas
		# polygon ear-clipping loses precision on tiny pigment strokes near x2000.
		# Translation belongs in the mesh transform, after all triangulation.
		var points:=PackedVector2Array()
		if polygon.has("local_points"):points=polygon.local_points
		else:
			for point in polygon.points:points.append(point-origin)
		var triangles:PackedInt32Array=Geometry2D.triangulate_polygon(points)
		if triangles.is_empty():continue # A sub-pixel pigment dab can collapse safely.
		var offset:int=vertices.size()
		for point in points:
			vertices.append(Vector3(point.x,point.y,0))
			colors.append(polygon.color)
		for index in triangles:indices.append(offset+index)
	if vertices.is_empty():return
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:ArrayMesh
	if canvas.has_method("record_draw_mesh"):
		# Captures preserve immutable meshes so successive poses cannot alias.
		mesh=ArrayMesh.new()
	else:
		var key:String=str(animal.get("uid",animal.species))
		if not _limb_meshes.has(key):_limb_meshes[key]=ArrayMesh.new()
		mesh=_limb_meshes[key]
		mesh.clear_surfaces()
		if _limb_meshes.size()>128:_limb_meshes.erase(_limb_meshes.keys()[0])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	if canvas.has_method("record_draw_mesh"):canvas.record_draw_mesh(mesh,null,Transform2D(0,origin))
	else:canvas.draw_mesh(mesh,null,Transform2D(0,origin))

static func draw(canvas:Object,animal:Dictionary,texture:Texture2D,pose:Dictionary,metadata:Dictionary,tint:Color=Color.WHITE)->void:
	var drawing:Dictionary=geometry(animal,metadata,pose,tint)
	_draw_limbs(canvas,animal,drawing.limbs)
	_polygon(canvas,drawing.body_points,tint,drawing.body_uvs,texture)

static func eye_offsets(animal:Dictionary,metadata:Dictionary,pose:Dictionary)->Array:
	var eyes:Array=[]
	var cfg:Dictionary=metadata.gait
	var rig:Dictionary=cfg.directions[int(pose.direction)]
	var phase:float=float(animal.get("gait_phase",float(animal.get("frame",0))/8.0))
	var bob:float=body_bob(str(animal.species),phase,bool(animal.get("moving",false)))
	for raw in rig.get("eyes",[]):eyes.append((_v(raw)+Vector2(0,bob)-pose.anchor)*float(pose.scale))
	return eyes
