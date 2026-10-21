extends RefCounted
## Design values live separately from the movement/encounter simulation.
## Ground contact sizes are world units; the painted animals may overhang them.
const SPECIES_ORDER := ["rabbit", "deer", "fox", "wolf", "bear"]
const SPECIES := {
	"rabbit": {"name":"Meadow rabbit", "periods":["day"], "cap":4,
		"ecology":{"roam":300.0,"idle":Vector2(0.8,3.6),"leg":Vector2(70,190),"memory":2.1,"escape":215.0},
		"health":18.0, "speed":43.0, "flee_speed":123.0, "notice":145.0,
		"feet":Vector2(8,4), "height":32.0, "stride":24.0, "predator":false,
		"ground":[Vector4(0,-2,8,4),Vector4(0,-2,11,5),Vector4(0,-2,13,5),Vector4(-1,-2,11,5),Vector4(0,-2,8,4),Vector4(1,-2,11,5),Vector4(0,-2,13,5),Vector4(0,-2,11,5)],
		"habitats":[Rect2(440,890,440,370),Rect2(1340,620,420,310),Rect2(1480,1020,460,300)]},
	"deer": {"name":"Woodland deer", "periods":["day"], "cap":3,
		"ecology":{"roam":520.0,"idle":Vector2(1.7,5.5),"leg":Vector2(115,330),"memory":3.0,"escape":295.0},
		"health":44.0, "speed":48.0, "flee_speed":128.0, "notice":190.0,
		"feet":Vector2(15,6), "height":70.0, "stride":52.0, "predator":false,
		"ground":[Vector4(0,-4,9,7),Vector4(-6,-5,25,9),Vector4(-9,-4,33,8),Vector4(-7,-5,25,10),Vector4(0,-4,9,7),Vector4(7,-5,25,10),Vector4(9,-4,33,8),Vector4(6,-5,25,9)],
		"habitats":[Rect2(550,800,430,460),Rect2(1300,940,620,370)]},
	"fox": {"name":"Red fox", "periods":["day","dusk"], "cap":2,
		"ecology":{"roam":460.0,"idle":Vector2(0.7,3.0),"leg":Vector2(100,290),"memory":2.6,"escape":260.0},
		"health":30.0, "speed":51.0, "flee_speed":115.0, "notice":170.0,
		"feet":Vector2(13,5), "height":42.0, "stride":34.0, "predator":false,
		"ground":[Vector4(0,-2,8,5),Vector4(-2,-3,16,7),Vector4(0,-3,19,6),Vector4(0,-3,12,6),Vector4(0,-2,8,5),Vector4(0,-3,12,6),Vector4(0,-3,19,6),Vector4(2,-3,16,7)],
		"habitats":[Rect2(520,220,400,350),Rect2(1370,260,440,380),Rect2(1670,900,390,360)]},
	"wolf": {"name":"Night wolf", "periods":["night"], "cap":3,
		"ecology":{"roam":580.0,"idle":Vector2(0.7,3.1),"leg":Vector2(140,360),"memory":3.4,"escape":0.0},
		"health":65.0, "speed":48.0, "chase_speed":116.0, "notice":265.0,
		"feet":Vector2(17,7), "height":48.0, "stride":42.0, "predator":true,
		"ground":[Vector4(0,-3,10,7),Vector4(-2,-3,23,8),Vector4(-1,-3,29,8),Vector4(0,-3,17,8),Vector4(0,-3,10,7),Vector4(0,-3,17,8),Vector4(1,-3,29,8),Vector4(2,-3,23,8)],
		"damage":12.0, "attack_range":43.0, "windup":0.65, "recovery":1.30,
		"habitats":[Rect2(450,160,490,350),Rect2(1350,230,470,400),Rect2(1450,980,580,370)]},
	"bear": {"name":"Forest bear", "periods":["night"], "cap":1,
		"ecology":{"roam":490.0,"idle":Vector2(1.6,5.2),"leg":Vector2(100,280),"memory":2.8,"escape":0.0},
		"health":125.0, "speed":35.0, "chase_speed":74.0, "notice":230.0,
		"feet":Vector2(26,11), "height":76.0, "stride":50.0, "predator":true,
		"ground":[Vector4(0,-5,25,12),Vector4(-3,-6,39,14),Vector4(-8,-5,49,12),Vector4(-7,-7,38,15),Vector4(0,-5,25,12),Vector4(7,-7,38,15),Vector4(8,-5,49,12),Vector4(3,-6,39,14)],
		"damage":22.0, "attack_range":65.0, "windup":0.95, "recovery":1.85,
		"habitats":[Rect2(120,140,650,380),Rect2(1500,800,520,550)]}
}
const CAMP := Vector2(455,725)
const CAMP_SAFE_RADIUS := 160.0
const GATE_PASSAGE := Vector2(1990,275)
const RESPAWN_DELAY := 28.0
const SPAWN_GRACE := 3.0
const PLAYER_HIT_GRACE := 1.10

static func info(species:String) -> Dictionary:
	return SPECIES.get(species,{})

static func active(species:String,period:String) -> bool:
	return period in info(species).get("periods",[])

static func ground(species:String,facing:Vector2) -> Vector4:
	# Fixed envelopes encompass the full walking cycle at each painted heading.
	# They cover paws/hooves on the ground, excluding heads, backs and tails.
	var heading:float=fposmod(rad_to_deg(atan2(facing.x,facing.y)),360.0)
	var direction:int=int(floor((heading+22.5)/45.0))%8
	var spec:Dictionary=info(species)
	if spec.has("ground"):return spec.ground[direction]
	var radii:Vector2=spec.get("feet",Vector2(10,6))
	return Vector4(0,-1,radii.x,radii.y)
