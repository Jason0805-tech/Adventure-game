extends SceneTree
# Builds ground-footprint collision profiles for the v0.1.7 beacon models.
# Physical collision is only the ground base (bottom band of the reference
# state); every state of one model shares the same WORLD footprint so swapping
# state can never trap an actor. Pixels are never resampled: textures are
# copied as-is, icons are only padded onto a square transparent canvas.
const GROUPS := [
	{"model":"beacon","states":["beacon-broken","beacon-repaired","beacon-lit"],"reference":"beacon-repaired","ref_height":190.0,"base":0.20,"inset":0.10},
	{"model":"rune_rock","states":["rune-rock","rune-rock-open"],"reference":"rune-rock","ref_height":74.0,"base":0.30,"inset":0.08},
	{"model":"shrine","states":["shrine-core","shrine-empty"],"reference":"shrine-empty","ref_height":60.0,"base":0.40,"inset":0.07},
]
const ICONS := ["part-lens","part-gear","part-core"]
func anchor(img:Image)->Vector2:
	# Same rule as main.gd load_art(): lowest solid row, alpha-weighted centre of
	# the bottom 8 percent.
	var sole:=img.get_height()-1
	for y in range(img.get_height()-1,-1,-1):
		var hit:=false
		for x in range(img.get_width()):
			if img.get_pixel(x,y).a>0.5:hit=true;break
		if hit:sole=y;break
	var total:=0.0;var wx:=0.0
	for y in range(maxi(0,sole-int(img.get_height()*0.08)),sole+1):
		for x in range(img.get_width()):
			var a:=img.get_pixel(x,y).a
			if a>0.5:total+=a;wx+=(x+0.5)*a
	return Vector2(wx/total if total>0 else img.get_width()*0.5,sole+1)
func extents(img:Image,y:int)->Vector2i:
	var l:=-1;var r:=-1
	for x in range(img.get_width()):
		if img.get_pixel(x,y).a>0.5:
			if l<0:l=x
			r=x
	return Vector2i(l,r)
func _initialize()->void:
	var src:String=OS.get_environment("SLICES");var out:String=OS.get_environment("ASSETS")
	var profiles:={};var models:={}
	for g in GROUPS:
		var ref:=Image.load_from_file(src.path_join(g.reference+".png"))
		var ref_anchor:=anchor(ref)
		var scale:float=float(g.ref_height)/ref.get_height() # world units per source pixel
		var top:int=int(ref_anchor.y-g.base*ref.get_height())
		var left:Array[Vector2]=[];var right:Array[Vector2]=[]
		var rows:=8
		for k in range(rows+1):
			var y:int=int(lerpf(top,ref_anchor.y-1,float(k)/rows))
			var e:=extents(ref,y)
			if e.x<0:continue
			var inset:float=(e.y-e.x)*float(g.inset)
			left.append((Vector2(e.x+inset,y)-ref_anchor)*scale)
			right.append((Vector2(e.y-inset,y)-ref_anchor)*scale)
		right.reverse()
		var world:Array[Vector2]=left+right
		var states:={}
		for s in g.states:
			var img:=Image.load_from_file(src.path_join(s+".png"))
			img.save_png(out.path_join(s+".png"))
			var a:=anchor(img)
			var size:=Vector2(img.get_width(),img.get_height())
			var poly:=[]
			var max_v:=0.0;var min_v:=1.0
			for p in world:
				var uv:Vector2=(a+p/scale)/size
				poly.append([snappedf(uv.x,0.001),snappedf(uv.y,0.001)])
				max_v=maxf(max_v,uv.y);min_v=minf(min_v,uv.y)
			var key:String=s.replace("-","_")
			profiles[key]={"polygons":[poly],"depth_v":snappedf(max_v-0.015,0.001),"overhead_split_v":snappedf(min_v,0.001),"collision_space":"ground_plane","notes":"v0.1.7 %s ground base: bottom %d%% of the %s reference silhouette, inset %d%% each side, shared world footprint across states. Elevated paint is visual only." % [g.model,int(g.base*100),g.reference,int(g.inset*100)]}
			states[s]={"profile":key,"height":snappedf(img.get_height()*scale,0.01)}
		models[g.model]=states
	for name in ICONS:
		var img:=Image.load_from_file(src.path_join(name+".png"))
		var side:=maxi(img.get_width(),img.get_height())
		var sq:=Image.create(side,side,false,Image.FORMAT_RGBA8)
		sq.blit_rect(img,Rect2i(Vector2i.ZERO,img.get_size()),Vector2i((side-img.get_width())/2,(side-img.get_height())/2))
		sq.save_png(out.path_join(name+".png"))
	var f:=FileAccess.open(out.path_join("beacon_models.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"models":models,"profiles":profiles},"  "))
	print(JSON.stringify(models))
	quit()
