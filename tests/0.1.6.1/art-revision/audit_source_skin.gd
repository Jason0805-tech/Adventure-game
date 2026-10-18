extends SceneTree
const PaintSkin=preload("/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6.1/art-revision/painted_skin.gd")
const Data=preload("res://wildlife_data.gd")
const ROOT="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech"
var source_bins:Dictionary={}
var report:Dictionary={"species":{},"checks":0,"issues":[]}
func _initialize()->void:call_deferred("_run")
func point(raw:Array)->Vector2:return Vector2(float(raw[0]),float(raw[1]))
func source_alpha(image:Image,p:Vector2,direction:int)->float:
	var x:int=clampi(floori(p.x),0,383)+direction*384
	var y:int=clampi(floori(p.y),0,383)
	return image.get_pixel(x,y).a
func visible(image:Image,points:PackedVector2Array,indices:PackedInt32Array,index:int,direction:int)->bool:
	var a:Vector2=points[indices[index]];var b:Vector2=points[indices[index+1]];var c:Vector2=points[indices[index+2]]
	for p in [a,b,c,(a+b+c)/3.0,(a+b)*.5,(b+c)*.5,(c+a)*.5]:
		if source_alpha(image,p,direction)>.1:return true
	return false
func prepare_bins(drawing:Dictionary)->void:
	source_bins.clear()
	for index in range(0,drawing.indices.size(),3):
		var a:Vector2=drawing.source_points[drawing.indices[index]];var b:Vector2=drawing.source_points[drawing.indices[index+1]];var c:Vector2=drawing.source_points[drawing.indices[index+2]]
		var lo:=Vector2(minf(a.x,minf(b.x,c.x)),minf(a.y,minf(b.y,c.y)))
		var hi:=Vector2(maxf(a.x,maxf(b.x,c.x)),maxf(a.y,maxf(b.y,c.y)))
		for y in range(floori(lo.y/4.0),floori(hi.y/4.0)+1):
			for x in range(floori(lo.x/4.0),floori(hi.x/4.0)+1):
				var key:=Vector2i(x,y)
				if not source_bins.has(key):source_bins[key]=[]
				source_bins[key].append(index)
func interpolate(drawing:Dictionary,p:Vector2)->Vector2:
	var key:=Vector2i(floori(p.x/4.0),floori(p.y/4.0))
	for index in source_bins.get(key,[]):
		var ia:int=drawing.indices[index];var ib:int=drawing.indices[index+1];var ic:int=drawing.indices[index+2]
		var a:Vector2=drawing.source_points[ia];var b:Vector2=drawing.source_points[ib];var c:Vector2=drawing.source_points[ic]
		var area:float=(b-a).cross(c-a)
		if absf(area)<.000001:continue
		var u:float=(p-a).cross(c-a)/area;var v:float=(b-a).cross(p-a)/area
		if u>=-.00001 and v>=-.00001 and u+v<=1.00001:return drawing.native_points[ia]*(1.0-u-v)+drawing.native_points[ib]*u+drawing.native_points[ic]*v
	push_error("Source skin triangulation leaves uncovered pixel "+str(p))
	return p

func sole(image:Image,leg:Dictionary,direction:int)->Array:
	var polygon:=PackedVector2Array()
	for raw in leg.paw_mask:polygon.append(point(raw))
	var points:Array=[]
	for x in range(384):
		for y in range(383,-1,-1):
			var p:=Vector2(x+.5,y+.5)
			if Geometry2D.is_point_in_polygon(p,polygon) and source_alpha(image,p,direction)>.1:
				points.append(p);break
	return points
func ground_excess(p:Vector2,g:Vector4)->float:
	var half_axis:float=maxf(0,g.z-g.w)
	var nearest:=Vector2(clampf(p.x-g.x,-half_axis,half_axis)+g.x,g.y)
	return maxf(0,p.distance_to(nearest)-g.w)
func _run()->void:
	var definitions:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/tests/0.1.6.1/art-revision/source_legs.json"))
	var meta:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animal_atlas.json"))
	for species in definitions.species:
		var image:=Image.load_from_file("res://assets/wildlife-"+species+".png")
		var scale:float=float(meta.species[species].world_height)/float(meta.species[species].reference_height_px)
		var directions:Dictionary={}
		for key in definitions.species[species]:
			var definition:Dictionary=definitions.species[species][key];var direction:int=int(definition.direction)
			var idle:Dictionary=PaintSkin.geometry(definition,0.0,false)
			prepare_bins(idle)
			var metric:Dictionary={"idle_exact":idle.source_points==idle.native_points,"fixed_uv":true,"visible_triangles":0,"flipped_visible_triangles":0,"collapsed_visible_triangles":0,"max_area_ratio":0.0,"min_area_ratio":INF,"sole_checks":0,"sole_outside":0,"max_sole_excess_world":0.0,"original_sole_outside":0,"original_sole_max_excess":0.0,"examples":[]}
			var visible_triangles:Array[int]=[]
			for index in range(0,idle.indices.size(),3):
				if visible(image,idle.source_points,idle.indices,index,direction):visible_triangles.append(index)
			metric.visible_triangles=visible_triangles.size()
			var soles:Array=[]
			var g:Vector4=Data.ground(species,Vector2.DOWN.rotated(-direction*PI/4.0))
			for leg in definition.legs:
				var samples:Array=sole(image,leg,direction);soles.append(samples)
				for sample in samples:
					var excess:float=ground_excess((sample-Vector2(192,320))*scale,g)
					if excess>.25:metric.original_sole_outside+=1
					metric.original_sole_max_excess=maxf(metric.original_sole_max_excess,excess)
			for frame in range(25):
				var phase:float=frame/24.0
				var drawing:Dictionary=PaintSkin.geometry(definition,phase,true)
				metric.fixed_uv=metric.fixed_uv and drawing.uvs==idle.uvs
				for index in visible_triangles:
					var a:Vector2=drawing.native_points[drawing.indices[index]];var b:Vector2=drawing.native_points[drawing.indices[index+1]];var c:Vector2=drawing.native_points[drawing.indices[index+2]]
					var sa:Vector2=idle.source_points[idle.indices[index]];var sb:Vector2=idle.source_points[idle.indices[index+1]];var sc:Vector2=idle.source_points[idle.indices[index+2]]
					var ratio:float=(b-a).cross(c-a)/(sb-sa).cross(sc-sa)
					metric.max_area_ratio=maxf(metric.max_area_ratio,ratio);metric.min_area_ratio=minf(metric.min_area_ratio,ratio)
					if ratio<-.001:
						metric.flipped_visible_triangles+=1
						if metric.examples.size()<5:metric.examples.append({"phase":phase,"triangle":index/3,"area_ratio":ratio})
					elif ratio<.001:metric.collapsed_visible_triangles+=1
				for i in range(definition.legs.size()):
					var leg:Dictionary=definition.legs[i]
					if fposmod(phase+float(leg.phase),1.0)>.5:continue
					for sample in soles[i]:
						metric.sole_checks+=1
						var warped:Vector2=interpolate(drawing,sample)
						var excess:float=ground_excess((warped-Vector2(192,320))*scale,g)
						if excess>.25:metric.sole_outside+=1
						metric.max_sole_excess_world=maxf(metric.max_sole_excess_world,excess)
			if not metric.idle_exact or not metric.fixed_uv or int(metric.flipped_visible_triangles)>0 or float(metric.max_sole_excess_world)>.5:report.issues.append(species+"/"+key)
			directions[key]=metric
			print("SKIN_AUDIT ",species,"/",key," ",metric)
		report.species[species]=directions
	var file:=FileAccess.open(ROOT+"/tests/0.1.6.1/art-revision/independent-skin-audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "));file.close()
	print("SOURCE_SKIN_AUDIT issues=",report.issues)
	quit(0 if report.issues.is_empty() else 1)
