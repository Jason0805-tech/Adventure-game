extends SceneTree
const ROOT := "/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech"
const OUT := ROOT+"/tests/0.1.6.1/gait"
const Gait=preload("res://animal_gait.gd")
const Data=preload("res://wildlife_data.gd")
var checks:=0
var errors:Array=[]
func check(ok:bool,note:String):
	checks+=1
	if not ok:errors.append(note)
func vec(p:Vector2)->Array:return [p.x,p.y]
func json_value(v:Variant)->Variant:
	if v is Vector2:return vec(v)
	if v is Color:return [v.r,v.g,v.b,v.a]
	if v is PackedVector2Array:
		var a:Array=[]
		for p in v:a.append(vec(p))
		return a
	if v is Array:
		var a:Array=[]
		for p in v:a.append(json_value(p))
		return a
	if v is Dictionary:
		var d:Dictionary={}
		for k in v:d[k]=json_value(v[k])
		return d
	return v
func _initialize():
	call_deferred("run")
func run():
	var metadata:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	var export:Dictionary={"species":{},"checks":0,"errors":[]}
	for species in Data.SPECIES_ORDER:
		var m:Dictionary=metadata.species[species]
		var scale:float=float(m.world_height)/float(m.reference_height_px)
		var directions:Array=[]
		for direction in range(8):
			var idle_animal:Dictionary={"species":species,"p":Vector2(192,320)*scale,"moving":false,"gait_phase":0.0,"state":"idle"}
			var idle_pose:Dictionary={"direction":direction,"scale":scale,"source":Rect2(direction*384,0,384,384),"anchor":Vector2(192,320)}
			var idle:Dictionary=Gait.geometry(idle_animal,m,idle_pose)
			for index in range(idle.limbs.size()):check(Geometry2D.triangulate_polygon(idle.limbs[index].points).size()>0,"Bad idle limb %s/%s/%s"%[species,direction,index])
			var poses:Array=[]
			var angle:float=deg_to_rad(direction*45.0)
			var facing:=Vector2(sin(angle),cos(angle))
			var ground:Vector4=Data.ground(species,facing)
			for frame in range(25):
				var animal:Dictionary={"species":species,"p":Vector2(192,320)*scale,"moving":true,"gait_phase":float(frame)/24.0,"state":"wander"}
				var pose:Dictionary={"direction":direction,"scale":scale,"source":Rect2(direction*384,0,384,384),"anchor":Vector2(192,320)}
				var drawing:Dictionary=Gait.geometry(animal,m,pose)
				for polygon in drawing.limbs:
					check(Geometry2D.triangulate_polygon(polygon.points).size()>0,"Bad limb polygon %s/%s/%s"%[species,direction,frame])
				var j:Array=drawing.joints
				check(j.size()==4,"Four joints missing %s/%s/%s"%[species,direction,frame])
				for leg in j:
					check(leg.root_point.is_finite() and leg.knee_point.is_finite() and leg.foot_point.is_finite(),"Nonfinite joint")
					# A support paw must lie within the existing registered ground
					# envelope. A raised recovery paw need not be a ground contact.
					if leg.cycle.y<0.01:
						var foot:Vector2=(leg.foot_point-Vector2(192,320))*scale
						var center:=Vector2(ground.x,ground.y)
						var half_axis:float=maxf(0.0,ground.z-ground.w)
						var nearest:=Vector2(clampf(foot.x-center.x,-half_axis,half_axis)+center.x,center.y)
						check(foot.distance_to(nearest)<=ground.w+.001,"Ground paw exceeds %s/%s/%s/%s foot=%s profile=%s"%[species,direction,frame,leg.name,foot,ground])
						var paw_axis:=Vector2(sin(angle),.20)
						var paw_points:PackedVector2Array=Gait._outline(leg.foot_point-paw_axis*float(m.gait.paw)*.20,leg.foot_point+paw_axis*float(m.gait.paw)*.58,float(leg.width)*.64,float(leg.width)*.55,71)
						for pixel in paw_points:
							var edge:Vector2=(pixel-Vector2(192,320))*scale
							var paw_center:=Vector2(ground.x,ground.y)
							var axis_half:float=maxf(0.0,ground.z-ground.w)
							var paw_nearest:=Vector2(clampf(edge.x-paw_center.x,-axis_half,axis_half)+paw_center.x,paw_center.y)
							check(edge.distance_to(paw_nearest)<=ground.w+.015,"Paw paint exceeds ground %s/%s/%s/%s"%[species,direction,frame,leg.name])
				# Body UVs and identity are invariant over the complete cycle.
				if frame>0:
					check(drawing.body_uvs==Gait.geometry({"species":species,"p":animal.p,"moving":true,"gait_phase":0.0,"state":"wander"},m,pose).body_uvs,"Body identity changed")
				poses.append(json_value(drawing))
			# Exact wrap; no endpoint ping-pong or one-frame body pop.
			check(JSON.stringify(poses[0])==JSON.stringify(poses[24]),"Loop seam differs "+species+"/"+str(direction))
			directions.append(poses)
		export.species[species]={"directions":directions,"scale":scale,"metadata":m}
	# The stance is monotonic rearward, while recovery has positive lift and
	# travels forward: this rejects the former mirrored/ping-pong faux cycle.
	for k in range(24):
		var a:=Gait.foot_cycle(float(k)/24.0,10.0,4.0)
		var b:=Gait.foot_cycle(float(k+1)/24.0,10.0,4.0)
		if k<12:check(b.x<=a.x+0.001 and a.y<.001,"Stance reverses/slides upwards")
		else:check(b.x>=a.x-.001,"Recovery reverses")
		if k>12 and k<24:check(a.y>0.0,"Recovery has no lift")
	# Native triangulation at the large world coordinates which exposed the
	# former tiny-brush degeneracy; test idle and moving, not origin-only shapes.
	for species in Data.SPECIES_ORDER:
		var m:Dictionary=metadata.species[species]
		for direction in range(8):
			for active in [false,true]:
				for phase in [0.0,.13,.49,.72,.999]:
					var animal:Dictionary={"species":species,"p":Vector2(2027.43,1328.17),"moving":active,"gait_phase":phase,"state":"chase"}
					var pose:Dictionary={"direction":direction,"scale":float(m.world_height)/float(m.reference_height_px),"source":Rect2(direction*384,0,384,384),"anchor":Vector2(192,320)}
					var drawing:Dictionary=Gait.geometry(animal,m,pose)
					check(Geometry2D.triangulate_polygon(drawing.body_points).size()>0,"Native large-coordinate body polygon")
					for polygon in drawing.limbs:check(Geometry2D.triangulate_polygon(polygon.local_points).size()>0,"Native local-coordinate limb mesh polygon")
	export.checks=checks;export.errors=errors
	var file:=FileAccess.open(OUT+"/gait-geometry.json",FileAccess.WRITE);file.store_string(JSON.stringify(export));file.close()
	print("GAIT_CHECKS ",checks," ERRORS ",errors.size())
	for note in errors.slice(0,30):print(note)
	quit(1 if errors.size()>0 else 0)
