extends SceneTree
# Prints the emptiest cut lines between painted objects in the beacon sheet.
func occ_col(img:Image,x:int,y0:int,y1:int)->int:
	var n:=0
	for y in range(y0,y1):
		if img.get_pixel(x,y).a>0.5:n+=1
	return n
func occ_row(img:Image,y:int,x0:int,x1:int)->int:
	var n:=0
	for x in range(x0,x1):
		if img.get_pixel(x,y).a>0.5:n+=1
	return n
func best_col(img,a,b,y0,y1)->Array:
	var best:=[1<<30,a]
	for x in range(a,b):
		var o:=occ_col(img,x,y0,y1)
		if o<best[0]:best=[o,x]
	return best
func best_row(img,a,b,x0,x1)->Array:
	var best:=[1<<30,a]
	for y in range(a,b):
		var o:=occ_row(img,y,x0,x1)
		if o<best[0]:best=[o,y]
	return best
func _initialize()->void:
	var img:=Image.load_from_file(OS.get_environment("SHEET"));img.convert(Image.FORMAT_RGBA8)
	print("top cuts (y0-480):")
	for r in [[400,520],[800,900],[1180,1290],[1560,1660]]:print(r," ",best_col(img,r[0],r[1],0,480))
	print("bottom cuts (y560-809):")
	for r in [[360,420],[680,720],[1010,1080],[1480,1530]]:print(r," ",best_col(img,r[0],r[1],560,809))
	print("row splits per column band:")
	for band in [[0,460],[460,850],[850,1235],[1235,1600],[1600,1944]]:print(band," ",best_row(img,480,620,band[0],band[1]))
	quit()
