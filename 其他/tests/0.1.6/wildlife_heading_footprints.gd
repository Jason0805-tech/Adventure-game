extends SceneTree
const Wildlife=preload("res://wildlife.gd")
const Data=preload("res://wildlife_data.gd")
const Geometry=preload("res://world_geometry.gd")
var checks:=0
var failures:Array[String]=[]
# Independent visible paw/hoof locations read from the registered source art,
# in world units about the fixed paint anchor. Not generated from colliders.
const PAWS={
	"rabbit":[[[-4,-2],[5,-2]],[[-7,-4],[8,-2]],[[-9,-2],[10,-2]],[[-9,-3],[7,-2]],[[-4,-2],[5,-2]],[[-7,-2],[9,-3]],[[-10,-2],[9,-2]],[[-8,-2],[7,-4]]],
	"deer":[[[-5,-3],[5,-1]],[[-27,-7],[11,-1]],[[-39,-1],[18,-2]],[[-29,-1],[10,-8]],[[-5,-1],[5,-2]],[[-12,-7],[29,-1]],[[-20,-2],[38,-1]],[[-11,-2],[26,-8]]],
	"fox":[[[-4,-2],[5,-2]],[[-10,-7],[7,-2]],[[-14,-2],[15,-2]],[[-7,-2],[7,-2]],[[-4,-2],[5,-2]],[[-7,-2],[7,-2]],[[-15,-2],[14,-2]],[[-7,-2],[10,-7]]],
	"wolf":[[[-5,-1],[6,-1]],[[-18,-8],[13,-2]],[[-24,-2],[24,-2]],[[-11,-1],[12,-3]],[[-7,-1],[7,-1]],[[-12,-3],[11,-1]],[[-24,-2],[24,-2]],[[-13,-2],[18,-8]]],
	"bear":[[[-18,-1],[18,-1]],[[-34,-8],[30,-2]],[[-50,-3],[34,-3]],[[-36,-4],[24,-9]],[[-18,-1],[18,-1]],[[-24,-9],[36,-4]],[[-34,-3],[50,-3]],[[-30,-2],[34,-8]]]
}

class Sandbox extends Node:
	var player:=Vector2(1600,1000)
	var npc_states:Dictionary={}
	var solid_bodies:Array[Dictionary]=[]
	var nav_grid:=AStarGrid2D.new()
	var nav_revision:=0
	var health:=100.0
	func _init()->void:
		nav_grid.region=Rect2i(0,0,184,125);nav_grid.cell_size=Vector2(12,12);nav_grid.offset=Vector2(6,6);nav_grid.update()
	func feet_polygon(p:Vector2)->PackedVector2Array:return Geometry.capsule_polygon(p+Vector2(0,-1),14,7,8)
	func body_active(_body:Dictionary)->bool:return true
	func nav_cell(p:Vector2)->Vector2i:return Vector2i(int(p.x/12),int(p.y/12))
	func take_damage(amount:float)->void:health-=amount

func _initialize()->void:call_deferred("_run")
func check(condition:bool,label:String)->void:
	checks+=1
	if not condition:failures.append(label);push_error("FAIL "+label)

func _run()->void:
	var game:=Sandbox.new();root.add_child(game)
	var sim:=Wildlife.new();sim.setup(game,16)
	var authored:Dictionary={}
	for species in Data.SPECIES_ORDER:
		authored[species]=[]
		for direction in range(8):
			var facing:=Vector2(sin(deg_to_rad(direction*45.0)),cos(deg_to_rad(direction*45.0)))
			var animal:Dictionary={"species":species,"uid":1,"facing":facing,"p":Vector2(1400,700)}
			var shape:PackedVector2Array=sim.footprint(animal,Vector2.ZERO)
			for raw in PAWS[species][direction]:
				check(Geometry.point_in_polygon_or_boundary(Vector2(raw[0],raw[1]),shape),"%s %d actual visible paw inside ground footprint"%[species,direction*45])
			check(not Geometry.point_in_polygon_or_boundary(Vector2(0,-float(Data.info(species).height)*.65),shape),"%s %d upper painted body is not a ground wall"%[species,direction*45])
			var ground:Vector4=Data.ground(species,facing)
			authored[species].append({"offset":[ground.x,ground.y],"half_size":[ground.z,ground.w],"paws":PAWS[species][direction]})
		check(Data.ground(species,Vector2.RIGHT).z>=Data.ground(species,Vector2.DOWN).z,"%s side stance does not inherit narrow front pose"%species)
	check(not Geometry.point_in_polygon_or_boundary(Vector2(15,-4),sim.footprint({"species":"deer","facing":Vector2.DOWN},Vector2.ZERO)),"front deer has no old invisible 30-wide boot wall")
	check(Data.info("bear").attack_range>Data.ground("bear",Vector2.LEFT).z-Data.ground("bear",Vector2.LEFT).x+14,"bear can reach player outside side ground contact")
	var bear:Dictionary={"species":"bear","uid":1,"facing":Vector2.DOWN,"p":Vector2(1400,700)}
	sim.animals=[bear]
	var wall:=Rect2(1350,680,20,40)
	var polygon:=PackedVector2Array([wall.position,wall.position+Vector2(wall.size.x,0),wall.end,wall.position+Vector2(0,wall.size.y)])
	game.solid_bodies=[{"bounds":wall,"polygon":polygon}]
	check(sim._ground_clear(game,bear,bear.p),"bear front stance initially clear beside wall")
	check(not sim._try_facing(game,bear,Vector2.RIGHT) and bear.facing==Vector2.DOWN,"turn cannot expand side paws into wall")
	check(sim._ground_clear(game,bear,bear.p),"rejected turn preserves legal footprint")
	bear.p=Vector2(1450,700)
	check(sim._try_facing(game,bear,Vector2.RIGHT),"bear turns once enough ground clearance exists")
	game.solid_bodies.clear();bear.p=Vector2(1400,700);bear.facing=Vector2.DOWN
	game.npc_states={"Ash":{"p":Vector2(1360,700)}}
	check(not sim._try_facing(game,bear,Vector2.RIGHT) and bear.facing==Vector2.DOWN,"turn cannot expand side paws into NPC")
	game.npc_states.clear();game.player=Vector2(1360,700)
	check(not sim._try_facing(game,bear,Vector2.RIGHT) and bear.facing==Vector2.DOWN,"turn cannot expand side paws into player")
	# An expanded side stance must still be able to approach far enough to attack.
	game.player=Vector2(1600,1000)
	for species in ["wolf","bear"]:
		for direction in range(8):
			sim.animals.clear();sim._spawn_one(game,species)
			var animal:Dictionary=sim.animals[0]
			var facing:=Vector2(sin(deg_to_rad(direction*45.0)),cos(deg_to_rad(direction*45.0)))
			animal.p=game.player-facing*140;animal.home=animal.p;animal.facing=facing
			animal.age=5.0;animal.state="idle";animal.timer=1.0
			sim.period="night";sim.respawn_in=28.0;sim.player_hit_grace=0.0;game.health=100
			var warned:=false
			var closest:=140.0
			for tick in range(180):
				sim.update(game,.05,"night")
				warned=warned or animal.state=="windup"
				closest=minf(closest,animal.p.distance_to(game.player))
				if game.health<100:break
			check(warned and game.health<100,"%s %d can reach warning and attack outside physical boot contact (closest %.2f)"%[species,direction*45,closest])
			check(not Geometry.polygons_overlap(sim.footprint(animal,animal.p),game.feet_polygon(game.player)),"%s %d attack never penetrates player feet"%[species,direction*45])
	var path:="/Users/jasonsmacair/Documents/Codex/adventure game program by AI tech/tests/0.1.6/footprint-audit/heading-ground-profiles.json"
	var output:=FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(authored,"\t"));output.close()
	print("WILDLIFE_HEADING_FOOTPRINTS checks=",checks," failures=",failures.size()," profiles=40 independent_paws=80")
	game.queue_free();quit(0 if failures.is_empty() else 1)
