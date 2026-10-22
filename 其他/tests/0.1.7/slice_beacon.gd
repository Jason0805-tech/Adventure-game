extends SceneTree
# Splits the user-supplied beacon sheet into separate sprites WITHOUT resampling:
# every output pixel is an unchanged source pixel. Objects are separated by
# full-resolution alpha connectivity; small detached paint (flame sparks, leaf
# flecks) joins the nearest large object. Output order follows NAMES.
const NAMES := ["beacon-broken","beacon-repaired","beacon-lit","rune-rock","rune-rock-open","part-lens","part-gear","part-core","shrine-core","shrine-empty"]
func _initialize()->void:
	var src:String=OS.get_environment("SHEET");var out:String=OS.get_environment("OUT")
	var img:=Image.load_from_file(src);img.convert(Image.FORMAT_RGBA8)
	var w:=img.get_width();var h:=img.get_height()
	var data:=img.get_data()
	var label:=PackedInt32Array();label.resize(w*h);label.fill(-1)
	var comps:Array=[]
	for start in range(w*h):
		if label[start]!=-1 or data[start*4+3]<=128:continue
		var id:=comps.size();var stack:=PackedInt32Array([start]);label[start]=id
		var x0:=w;var y0:=h;var x1:=0;var y1:=0;var n:=0;var solid:=0
		while stack.size()>0:
			var j:int=stack[stack.size()-1];stack.resize(stack.size()-1)
			var x:=j%w;var y:=j/w;n+=1
			if data[j*4+3]>128:solid+=1
			x0=mini(x0,x);y0=mini(y0,y);x1=maxi(x1,x);y1=maxi(y1,y)
			if x+1<w and label[j+1]==-1 and data[(j+1)*4+3]>128:label[j+1]=id;stack.append(j+1)
			if x>0 and label[j-1]==-1 and data[(j-1)*4+3]>128:label[j-1]=id;stack.append(j-1)
			if y+1<h and label[j+w]==-1 and data[(j+w)*4+3]>128:label[j+w]=id;stack.append(j+w)
			if y>0 and label[j-w]==-1 and data[(j-w)*4+3]>128:label[j-w]=id;stack.append(j-w)
		comps.append({"id":id,"n":n,"solid":solid,"box":Rect2i(x0,y0,x1-x0+1,y1-y0+1)})
	# Soft edges (alpha 9-128) join whichever solid paint reaches them first.
	var frontier:=PackedInt32Array()
	for j in range(w*h):
		if label[j]>=0:frontier.append(j)
	var head:=0
	while head<frontier.size():
		var j:int=frontier[head];head+=1
		var x:=j%w
		for k in [j+1 if x+1<w else -1,j-1 if x>0 else -1,j+w if j+w<w*h else -1,j-w]:
			if k>=0 and label[k]==-1 and data[k*4+3]>8:label[k]=label[j];frontier.append(k)
	# Two painted objects that touch are split by growing from each object's
	# centre at the same speed; the seam falls at their narrow contact.
	for c in comps.duplicate():
		var parts:int=roundi(float(c.box.size.x)/390.0)
		if c.solid<8000 or parts<2:continue
		var ids:Array[int]=[c.id]
		for k in range(1,parts):
			ids.append(comps.size());comps.append({"id":comps.size(),"n":0,"solid":0,"box":Rect2i()})
		var queue:=PackedInt32Array()
		for k in range(parts):
			var seed:=Vector2i(c.box.position.x+int(c.box.size.x*(k+0.5)/parts),c.box.get_center().y)
			var found:=-1
			for r in range(0,200):
				for dx in range(-r,r+1):
					for dy in [-r,r]:
						var q:=Vector2i(seed.x+dx,seed.y+dy)
						if q.x>=0 and q.y>=0 and q.x<w and q.y<h and label[q.y*w+q.x]==c.id and data[(q.y*w+q.x)*4+3]>128:found=q.y*w+q.x;break
					if found>=0:break
				if found>=0:break
			label[found]=-2-ids[k];queue.append(found)
		var at:=0
		while at<queue.size():
			var j:int=queue[at];at+=1
			var x:=j%w
			for nb in [j+1 if x+1<w else -1,j-1 if x>0 else -1,j+w if j+w<w*h else -1,j-w]:
				if nb>=0 and label[nb]==c.id:label[nb]=label[j];queue.append(nb)
		for k in range(parts):
			var o:Dictionary=comps[ids[k]];o.n=0;o.solid=0;var first:=true
			for j in range(w*h):
				if label[j]==-2-ids[k]:
					label[j]=ids[k];o.n+=1
					if data[j*4+3]>128:o.solid+=1
					var r:=Rect2i(j%w,j/w,1,1);o.box=r if first else o.box.merge(r);first=false
	var big:=comps.filter(func(c):return c.solid>8000)
	print("components=",comps.size()," big=",big.size())
	for c in big:print(c.box," solid=",c.solid)
	if big.size()!=NAMES.size():
		push_error("Expected %d objects" % NAMES.size());quit(1);return
	# Reading order: top row (centre y above the sheet middle) then bottom row.
	big.sort_custom(func(a,b):
		var ra:int=0 if a.box.get_center().y<h*0.55 else 1
		var rb:int=0 if b.box.get_center().y<h*0.55 else 1
		return ra<rb if ra!=rb else a.box.position.x<b.box.position.x)
	var owner:=PackedInt32Array();owner.resize(comps.size());owner.fill(-1)
	for i in range(big.size()):owner[big[i].id]=i
	for c in comps:
		if owner[c.id]!=-1 or c.n<4:continue
		var best:=-1;var dist:=INF
		for i in range(big.size()):
			var b:Rect2i=big[i].box
			# Gap between the two boxes, so a pebble joins the object it sits beside.
			var gap:=Vector2(maxi(0,maxi(b.position.x-c.box.end.x,c.box.position.x-b.end.x)),maxi(0,maxi(b.position.y-c.box.end.y,c.box.position.y-b.end.y))).length()
			if gap<=40 and gap<dist:dist=gap;best=i
		owner[c.id]=best
	var report:={}
	for i in range(big.size()):
		var box:Rect2i=Rect2i()
		var first:=true
		for c in comps:
			if owner[c.id]==i:box=c.box if first else box.merge(c.box);first=false
		box=box.grow(4).intersection(Rect2i(0,0,w,h))
		var piece:=Image.create(box.size.x,box.size.y,false,Image.FORMAT_RGBA8)
		for y in range(box.size.y):
			for x in range(box.size.x):
				var j:=(box.position.y+y)*w+box.position.x+x
				var l:=label[j]
				if l>=0 and owner[l]==i:piece.set_pixel(x,y,img.get_pixel(box.position.x+x,box.position.y+y))
		piece.save_png(out.path_join(NAMES[i]+".png"))
		report[NAMES[i]]={"source_rect":[box.position.x,box.position.y,box.size.x,box.size.y]}
		print(NAMES[i]," ",box)
	var f:=FileAccess.open(out.path_join("beacon-slices.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"source":src.get_file(),"resampled":false,"objects":report},"  "))
	quit()
