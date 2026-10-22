extends SceneTree
# Lists connected painted objects in the beacon sheet (coarse 6px grid).
func _initialize()->void:
	var img:=Image.load_from_file(OS.get_environment("SHEET"))
	img.convert(Image.FORMAT_RGBA8)
	var c:=6;var w:=img.get_width()/c+1;var h:=img.get_height()/c+1
	var grid:=PackedByteArray();grid.resize(w*h)
	for y in range(img.get_height()):
		for x in range(0,img.get_width(),2):
			if img.get_pixel(x,y).a>0.5:grid[(y/c)*w+x/c]=1
	var seen:=PackedByteArray();seen.resize(w*h)
	var boxes:=[]
	for i in range(w*h):
		if grid[i]==0 or seen[i]==1:continue
		var stack:=[i];seen[i]=1;var x0:=w;var y0:=h;var x1:=0;var y1:=0;var n:=0
		while not stack.is_empty():
			var j:int=stack.pop_back();var x:=j%w;var y:=j/w;n+=1
			x0=mini(x0,x);y0=mini(y0,y);x1=maxi(x1,x);y1=maxi(y1,y)
			for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var nx:int=x+d.x;var ny:int=y+d.y
				if nx<0 or ny<0 or nx>=w or ny>=h:continue
				var k:=ny*w+nx
				if grid[k]==1 and seen[k]==0:seen[k]=1;stack.append(k)
		boxes.append([n,x0*c,y0*c,(x1+1)*c,(y1+1)*c])
	boxes.sort_custom(func(a,b):return a[0]>b[0])
	for b in boxes.slice(0,24):print(b)
	quit()
