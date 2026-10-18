extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func run():
 var g=load("res://main.gd").new();g.resource_seed=152;g.build_world()
 const STEP=22.0
 const COLS=97
 const ROWS=65
 var grid=PackedByteArray();grid.resize(COLS*ROWS)
 for y in range(ROWS):
  for x in range(COLS):
   if g.walkable(Vector2(40+x*STEP,40+y*STEP)):grid[y*COLS+x]=1
 var queue:Array[int]=[]
 var start_x=int(round((g.player.x-40)/STEP));var start_y=int(round((g.player.y-40)/STEP))
 var start=start_y*COLS+start_x
 grid[start]=2;queue.append(start);var head:=0
 while head<queue.size():
  var cell:int=queue[head];head+=1
  var x=cell%COLS;var y=cell/COLS
  for shift in [Vector2i(-1,0),Vector2i(1,0),Vector2i(0,-1),Vector2i(0,1)]:
   var nx=x+shift.x;var ny=y+shift.y
   if nx<0 or nx>=COLS or ny<0 or ny>=ROWS:continue
   var neighbor=ny*COLS+nx
   if grid[neighbor]==1:grid[neighbor]=2;queue.append(neighbor)
 for item in g.items:
  var reached:=false
  var cx=int((item.pos.x-40)/STEP);var cy=int((item.pos.y-40)/STEP)
  for y in range(maxi(0,cy-3),mini(ROWS,cy+4)):
   for x in range(maxi(0,cx-3),mini(COLS,cx+4)):
    if grid[y*COLS+x]!=2:continue
    var point=Vector2(40+x*STEP,40+y*STEP)
    g.player=point
    if point.distance_to(item.pos)<75 and g.target_line_clear(item.pos):reached=true
  if not reached:failures+=1;push_error("Unreachable node: "+str(item))
 print("NAVIGATION_RESULT: ",g.items.size()," reachable nodes checked, ",failures," failures; visited ",queue.size()," ground cells")
 g.free();quit(1 if failures else 0)
