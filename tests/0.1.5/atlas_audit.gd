extends SceneTree
func _initialize():
 var sheets = [["environment",3,[0.0,0.54,1.0]], ["tree-variants",3,[0.0,0.61,1.0]], ["equipment",4,[0.0,0.5,1.0]], ["materials",3,[0.0,0.36,0.67,1.0]], ["ponds",1,[0.0,0.38,0.71,1.0]], ["traveler-directions",4,[0.0,0.5,1.0]], ["npcs",2,[0.0,0.5,1.0]], ["ground-blends",3,[0.0,0.5,1.0]]]
 for entry in sheets:
  var im = Image.load_from_file(ProjectSettings.globalize_path("res://assets/"+entry[0]+".png"))
  var seams = 0
  for c in range(1,entry[1]):
   var x = int(float(c)*im.get_width()/entry[1])
   for y in range(im.get_height()):
    if im.get_pixel(x,y).a > 0.5: seams += 1
  for r in range(1,entry[2].size()-1):
   var y = int(entry[2][r]*im.get_height())
   for x in range(im.get_width()):
    if im.get_pixel(x,y).a > 0.5: seams += 1
  print(entry[0]," SOLID_PIXELS_CROSSING_CELL_BOUNDARIES=",seams)
 quit()
