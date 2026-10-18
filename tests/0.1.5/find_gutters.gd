extends SceneTree
func _initialize():
 for entry in [["environment",3,[0.0,0.54,1.0]], ["tree-variants",3,[0.0,0.61,1.0]], ["ponds",1,[0.0,0.38,0.71,1.0]], ["ground-blends",3,[0.0,0.5,1.0]]]:
  var im = Image.load_from_file(ProjectSettings.globalize_path("res://assets/"+entry[0]+".png"))
  print(entry[0], " size=",im.get_size())
  for r in range(1,entry[2].size()-1):
   var expected=int(entry[2][r]*im.get_height())
   var best=expected; var cost=INF;var occupied=0
   for y in range(maxi(0,expected-100),mini(im.get_height(),expected+100)):
    var n=0
    for x in range(im.get_width()):
     if im.get_pixel(x,y).a > 0.5:n+=1
    var candidate=n+abs(y-expected)*0.001
    if candidate<cost:cost=candidate;best=y;occupied=n
   print(" row ",r," best=",best," alpha=",occupied)
  for r in range(entry[2].size()-1):
   for c in range(1,entry[1]):
    var expected=int(float(c)*im.get_width()/entry[1])
    var best=expected;var cost=INF;var occupied=0
    for x in range(maxi(0,expected-100),mini(im.get_width(),expected+100)):
     var n=0
     for y in range(int(entry[2][r]*im.get_height()),int(entry[2][r+1]*im.get_height())):
      if im.get_pixel(x,y).a > 0.5:n+=1
     var candidate=n+abs(x-expected)*0.001
     if candidate<cost:cost=candidate;best=x;occupied=n
    print(" cellrow ",r," column ",c," best=",best," alpha=",occupied)
 quit()
